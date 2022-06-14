
//
// Sort, index BAM file and run samtools stats, flagstat and idxstats
// COPIED FROM nf-co/rnaseq
//

include { SORT_INDEX_STATS } from './nf-core/samtools_sort_index_stats'
include { ADD_RG_AND_TAGS  } from '../../modules/local/add_read_group'
include { MPILEUP           } from '../../modules/nf-core/modules/samtools/mpileup/main'

workflow SAMTOOLS_SORT_INDEX_STATS {
    take:
    bam // channel: [ val(meta), [ bam ] ]
    genome // path(genome) path to the fasta file
    fai // path(fasta index) path to the index of the genome fasta file

    main:

    ch_versions = Channel.empty()

    SORT_INDEX_STATS(
        ch_bam
    )
    ch_versions = ch_versions.mix(SORT_INDEX_STATS.out.versions)

    ADD_RG_AND_TAGS (
        SORT_INDEX_STATS.out.bam_index,
        genome,
        fai
    )
    ch_version = ch_versions.mix(ADD_RG_TAGS.out.versions)

    MPILEUP(
        bam
        genome
    )
    ch_versions = ch_versions.mix(PILEUP.out.versions)


    emit:
    // bam_index = ADD_RG_AND_TAGS.out.bam_index // channel: [ val(meta), [ bam ], [ bai ] ]
    stats     = SORT_INDEX_STATS.out.stats    // channel: [ val(meta), [ stats ] ]
    flagstat  = SORT_INDEX_STATS.out.flagstat // channel: [ val(meta), [ flagstat ] ]
    idxstats  = SORT_INDEX_STATS.out.idxstats // channel: [ val(meta), [ idxstats ] ]
    mpileup   = MPILEUP.out.mpileup           // channel: [ val(meta), [ mpileup ] ]
    versions  = ch_versions                   // channel: [ versions.yml ]

}
