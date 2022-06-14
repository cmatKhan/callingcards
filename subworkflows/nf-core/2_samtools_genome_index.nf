//
// Index the reference genome and align reads
//

include { SAMTOOLS_FAIDX } from '../../modules/nf-core/modules/samtools/faidx/main'

workflow SAMTOOLS_INDEX_GENOME {
    take:
    genome   // path(genome)

    main:

    ch_versions = Channel.empty()

    //
    // index the genome with bwamem2 index
    //
    ch_genome = Channel.of( ['', genome]
    SAMTOOLS_FAIDX ( ch_genome )
    ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

    emit:
    genome_index   = SAMTOOLS_FAIDX.out.fai.last()  // channel: path(*.fai)
    versions       = ch_versions             // channel: [ versions.yml ]
}
