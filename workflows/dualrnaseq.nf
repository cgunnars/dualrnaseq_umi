/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//

//subworkflow and module inclusion
include { PREPARE_REFERENCE_FILES         } from '../subworkflows/local/prepare_reference_files'
include { SALMON_SELECTIVE_ALIGNMENT      } from '../subworkflows/local/salmon_selective_alignment'
include { SALMON_ALIGNMENT_BASED          } from '../subworkflows/local/salmon_alignment_based'
include { STAR_HTSEQ as STAR_ALIGNMENT    } from '../subworkflows/local/star_htseq'
include { softwareVersionsToYAML           } from '../subworkflows/nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                          } from '../modules/nf-core/fastqc'
include { FASTQC as FASTQC_AFTER_TRIMMING } from '../modules/nf-core/fastqc'
include { CUTADAPT                        } from '../modules/nf-core/cutadapt'
include { MULTIQC                         } from '../modules/nf-core/multiqc'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DUALRNASEQ {
    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // Collect versions from topic channels
    def topic_versions = channel.topic("versions")
      .distinct()
      .branch { entry ->
          versions_file: entry instanceof Path
          versions_tuple: true
      }
    def topic_versions_string = topic_versions.versions_tuple
      .map { process, tool, version ->
          [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
      }
      .groupTuple(by:0)
      .map { process, tool_versions ->
          tool_versions.unique().sort()
          "${process}:\n${tool_versions.join('\n')}"
      }


    // Initialize required channels
    //ch_workflow_summary = Channel.empty()
    //ch_methods_description = Channel.empty()
    ch_multiqc_config = Channel.fromPath("${projectDir}/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()
    ch_multiqc_logo = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo) : Channel.empty()

    // Removed validate samplesheet as had constant issues and errors
    // If you want to spend the time trying - go ahead
    ch_reads = ch_samplesheet

    if (params.fastqc) {
        FASTQC(ch_samplesheet)
        ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect { it[1] })
    }

    if (params.cutadapt) {
        CUTADAPT(ch_samplesheet)
        ch_reads = CUTADAPT.out.reads
    }

    if (params.fastqc && params.cutadapt) {
        FASTQC_AFTER_TRIMMING(ch_reads)
    }


    // ---------------
    // Prepare reference files
    // ---------------
    // uncompress files, merge host and pathogen files together,
    // update features in reference files to be compatable with software
    PREPARE_REFERENCE_FILES(
        params.host_fasta_genome,
        params.host_gff,
        params.pathogen_fasta_genome,
        params.pathogen_gff,
    )


    if (params.salmon_sa) {
        SALMON_SELECTIVE_ALIGNMENT(
            ch_reads,
            PREPARE_REFERENCE_FILES.out.host_pathogen_fasta_genome,
            PREPARE_REFERENCE_FILES.out.host_pathogen_fasta_transcripts,
            PREPARE_REFERENCE_FILES.out.host_pathogen_transcripts_gff,
            PREPARE_REFERENCE_FILES.out.pathogen_fasta_transcripts,
            PREPARE_REFERENCE_FILES.out.host_fasta_transcripts,
            PREPARE_REFERENCE_FILES.out.annotations_host_salmon,
        )
        ch_versions = ch_versions.mix(SALMON_SELECTIVE_ALIGNMENT.out.versions)
    }
    if (params.salmon_ab) {
        SALMON_ALIGNMENT_BASED(
            ch_reads,
            PREPARE_REFERENCE_FILES.out.host_pathogen_fasta_genome,
            PREPARE_REFERENCE_FILES.out.host_pathogen_fasta_transcripts,
            PREPARE_REFERENCE_FILES.out.host_pathogen_transcripts_gff,
            PREPARE_REFERENCE_FILES.out.pathogen_fasta_transcripts,
            PREPARE_REFERENCE_FILES.out.host_fasta_transcripts,
            PREPARE_REFERENCE_FILES.out.annotations_host_salmon,
        )
        ch_versions = ch_versions.mix(SALMON_ALIGNMENT_BASED.out.versions)
    }

    // Run if STAR genome alignment
    if (params.star) {
        STAR_ALIGNMENT(
            ch_reads,
            PREPARE_REFERENCE_FILES.out.host_pathogen_fasta_genome,
            PREPARE_REFERENCE_FILES.out.host_pathogen_genes_gff,
        )
    }

    

    ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_dualrnaseq_versions.yml', sort: true, newLine: true)

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        [],
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions // channel: [ path(versions.yml) ]
}
