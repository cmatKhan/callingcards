/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap; fromSamplesheet } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowCallingcards.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { PREPARE_GENOME     } from '../subworkflows/local/prepare_genome'
include { PREPARE_READS      } from '../subworkflows/local/mammals/prepare_reads'
include { ALIGN              } from '../subworkflows/local/align'
include { PROCESS_ALIGNMENTS } from '../subworkflows/local/mammals/process_alignments'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE PARAMS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

if(params.fasta){
    ch_fasta = Channel.fromPath(params.fasta, checkIfExists: true).collect()
} else {
    exit 1, 'Either a valid configured `genome` or a `fasta` file must be specified.'
}

if(params.gtf){
    ch_gtf = Channel.fromPath(params.gtf, checkIfExists:true).collect()
} else {
    exit 1, 'Either a valid configured `genome` or a `gtf` file must be specified.'
}


ch_regions_mask = params.regions_mask ?
        Channel.fromPath(params.regions_mask, checkIfExists: true)
                .collect().map{ it -> [[id:it[0].getSimpleName()], it[0]]} :
        Channel.empty()

additional_fasta = params.additional_fasta ?
        Channel.fromPath(params.additional_fasta, checkIfExists: true).collect() :
        Channel.empty()

def rseqc_modules = params.rseqc_modules ?
    params.rseqc_modules.split(',').collect{ it.trim().toLowerCase() } :
    []

// Check that nonsensical combinations of parameters are not set
if (params.additional_fasta && (params.bwa_index || params.bwamem2_index || params.bowtie_index || params.bowtie2_index)) {
    exit 1, 'You have specified an additional fasta file and a genome index.' +
    ' If the genome index is not equivalent to the main fasta file,' +
    ' then omit the index and allow the pipeline to create it from' +
    ' the concatenated fasta files.'
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow CALLINGCARDS_MAMMALS {

    ch_versions          = Channel.empty()
    ch_fasta_index       = Channel.empty()
    ch_bam_index         = Channel.empty()
    ch_samtools_stats    = Channel.empty()
    ch_samtools_flatstat = Channel.empty()
    ch_samtools_idxstats = Channel.empty()

    //
    // VALIDATE AND PARSE INPUTS
    //
    Channel.fromSamplesheet("input")
        .multiMap{ sample, fastq_1, fastq_2, barcode_details ->
            def single_end = fastq_2.size() == 0
            if (!single_end){
                log.info"Only the first read of the pair will be used for sample ${sample}"
                single_end = True
            }
            def meta = ["id": sample, "single_end": single_end]
            reads: [meta, [fastq_1]]
            barcode_details: [meta, barcode_details]}
        .set{ ch_input }

    //
    // SUBWORKFLOW_2: Index the genome in various ways
    //
    // input: fasta file (genome), a regions mask (bed format), additional
    //        sequences (fasta format) to append to the genome after masking,
    //        and a gtf file
    // output: fasta (masked fasta), fai (fasta index),
    //         genome_bed (gtf in bed format), bwamem2_index (bwa mem2 index),
    //         bwa_index (bwa aln index), bowtie_index (bowtie index),
    //         bowtie2_index (bowtie2 index), versions
    //         NOTE: the aligner index channels will be empty except for the
    //         aligner specified in params.aligner
    PREPARE_GENOME(
        ch_fasta,
        ch_regions_mask,
        additional_fasta,
        ch_gtf
    )
    ch_versions = ch_versions.mix(PREPARE_GENOME.out.versions)

    //
    // SUBWORKFLOW_3: run sequencer level QC, extract barcodes and trim
    // input: [ val(meta), [ path(fastq1), path(fastq2) ] ] where the reads
    //        list may be [ path(fastq1) ] if the input is single-end
    // output: 'reads' with structure [ val(meta), [ path(fastq1),
    //                                               path(fastq2) ] ]
    //         'fastqc_html' with structure [ val(meta), path(fastqc_html) ]
    //         'fastqc_zip' with structure [ val(meta), path(fastqc_zip) ]
    //         'umi_log' with structure [ val(meta), path(umi_log) ]
    //         'trimmomatic_log' with structure [ val(meta),
    //                                            path(trimmomatic_log) ]
    //         'versions' with structure [ path(versions) ]
    PREPARE_READS (
        ch_input.reads
    )
    ch_versions = ch_versions.mix(PREPARE_READS.out.versions)

    //
    // SUBWORKFLOW_4: align reads
    // input: post-processed reads. note that the fastq have been split into
    //        chunks based on params.split_fastq_chunk_size. the metadata
    //        includes a key value pair split: <split_number>, eg split: 1
    // output: channel 'bam' with structure [ val(meta), path(bam), path(bai) ]
    //         channel 'versions' with structure [ path(versions) ]
    ALIGN (
        PREPARE_READS.out.reads,
        PREPARE_GENOME.out.bwamem2_index,
        PREPARE_GENOME.out.bwa_index,
        PREPARE_GENOME.out.bowtie2_index,
        PREPARE_GENOME.out.bowtie_index
    )
    ch_versions = ch_versions.mix(ALIGN.out.versions)

    // join the alignment output with the ch_input.barcode_details
    // to create a channel with structure:
    // [val(meta), path(bam), path(bai), path(barcode_details)]
    ALIGN.out.bam
        .map{meta, bam, bai -> [meta.id, meta, bam, bai] }
        .combine(ch_input.barcode_details
                    .map{meta, barcode_details ->
                            [meta.id, barcode_details]},
                by: 0)
        .map{id, meta, bam, bai, barcode_details ->
                [meta, bam, bai, barcode_details] }
        .set{ ch_aln_with_details }

    //
    // SUBWORKFLOW_5: process the alignnment into a qbed file
    // input: channel 'bam' with structure [ val(meta), path(bam),
    //                                       path(bai), path(barcode_details) ],
    //       'fasta' (genome fasta), 'genome_bed' (genome bed),
    //       'rseqc_modules' (list of rseqc modules to run),
    //       'fai' [val(meta), path(fai)], 'gtf' (gtf file),
    //       'biotypes_header_multiqc' (biotypes header for multiqc)
    // output: All QC outputs have structure [ val(meta), path(file) ]
    //         'samtools_stats', 'samtools_flatstat', 'samtools_idxstats',
    //         'picard_qc', 'rseqc_bamstat', 'rseqc_infer_experiment',
    //         'rseqc_inner_distance', 'rseqc_read_distribution',
    //         'rseqc_read_duplication', 'rseqc_tin',
    //         'versions'
    PROCESS_ALIGNMENTS (
        ch_aln_with_details,
        ch_fasta,
        PREPARE_GENOME.out.fai,
        PREPARE_GENOME.out.genome_bed,
        rseqc_modules,
        ch_gtf
    )
    ch_versions = ch_versions.mix(PROCESS_ALIGNMENTS.out.versions)

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowCallingcards.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)
                            .collectFile(name: 'workflow_summary_mqc.yaml')

    methods_description    = WorkflowCallingcards.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)
                                .collectFile(name: 'methods_description_mqc.yaml')

    // collect process reads logs,etc
    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(PREPARE_READS.out.fastqc_zip
        .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(PREPARE_READS.out.fastqc_zip
        .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(PREPARE_READS.out.trimmomatic_log
        .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files
        .mix(PROCESS_ALIGNMENTS.out.samtools_stats
            .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files
        .mix(PROCESS_ALIGNMENTS.out.samtools_flagstat
            .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files
        .mix(PROCESS_ALIGNMENTS.out.samtools_idxstats
            .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files
        .mix(PROCESS_ALIGNMENTS.out.picard_qc
            .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files
        .mix(PROCESS_ALIGNMENTS.out.rseqc_bamstat
            .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
	ch_multiqc_files = ch_multiqc_files
        .mix(PROCESS_ALIGNMENTS.out.rseqc_inferexperiment
            .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
	ch_multiqc_files = ch_multiqc_files
        .mix(PROCESS_ALIGNMENTS.out.rseqc_innerdistance
            .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
	ch_multiqc_files = ch_multiqc_files
        .mix(PROCESS_ALIGNMENTS.out.rseqc_readdistribution
            .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
	ch_multiqc_files = ch_multiqc_files
        .mix(PROCESS_ALIGNMENTS.out.rseqc_readduplication
            .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))
	ch_multiqc_files = ch_multiqc_files
        .mix(PROCESS_ALIGNMENTS.out.rseqc_tin
            .map{meta, qc -> [['id': (meta.id)], qc]}.ifEmpty([]))

    ch_multiqc_files
        .filter{item -> item.size() > 0}
        .groupTuple()
        .map{meta, qc -> [meta, qc.flatten()]}
        .combine(ch_multiqc_config)
        .map{ it -> [it[0], it[1].plus(it[2..-1].flatten())] }
        .set{ ch_multiqc_files_grouped }

    MULTIQC (
        ch_multiqc_files_grouped,
        ch_workflow_summary,
        ch_methods_description,
        CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
