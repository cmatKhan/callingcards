/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowCallingcards.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input,
                           params.multiqc_config,
                           params.fasta ]

for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK      } from '../subworkflows/local/input_check'
include { FASTQC_UMITOOLS  } from '../subworkflows/nf-core/fastqc_umitools'
include { BWAMEM2_SAMTOOLS } from '../subworkflows/nf-core/bwamem2_samtools'
include { PILEUP_BY_GROUP }         from '../subworkflows/nf-core/pileup_by_group'

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/modules/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow CALLINGCARDS {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // MODULESUBWORKFLOW: Use umi_tools to add barcodes to fastq id lines
    FASTQC_UMITOOLS (
        INPUT_CHECK.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC_UMITOOLS.out.versions.first())

    // MODULE: Align with bwamem2
    ch_genome_bam                 = Channel.empty()
    ch_genome_bam_index           = Channel.empty()
    ch_samtools_stats             = Channel.empty()
    ch_samtools_flagstat          = Channel.empty()
    ch_samtools_idxstats          = Channel.empty()
    ch_aligner_clustering_multiqc = Channel.empty()

    BWAMEM2_SAMTOOLS (
        FASTQC_UMITOOLS.out.reads,
        params.fasta
    )
    // parse output into separate channels
    ch_genome_bam        = BWAMEM2_SAMTOOLS.out.bam
    ch_samtools_stats    = BWAMEM2_SAMTOOLS.out.stats
    ch_samtools_flagstat = BWAMEM2_SAMTOOLS.out.flagstat
    ch_samtools_idxstats = BWAMEM2_SAMTOOLS.out.idxstats
    ch_versions = ch_versions.mix(BWAMEM2_SAMTOOLS.out.versions.first())

    //
    // MODULE: run BamQC
    // BAMQC (
    //    ALIGN.out.bams // NOTE NEED TO SPLIT THIS ? HOW HANDLED IN RNASEQ?
    // )
    //ch_versions = ch_versions.mix(BAMQC.out.versions.first())

    // MODULE: Run Quantification QC
    PILEUP_BY_GROUP (
       ch_genome_bam,
       params.fasta
    )
    ch_versions = ch_versions.mix(PILEUP_BY_GROUP.out.versions.first())

    //
    // collect software versions into file
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowCallingcards.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(ch_samtools_stats.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_samtools_flagstat.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_samtools_idxstats.collect{it[1]}.ifEmpty([]))
    // add BAMQC output here, also -- see RNAseq pipeline


    MULTIQC (
        ch_multiqc_files.collect()
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
