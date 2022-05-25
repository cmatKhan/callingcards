
//
// Sort, index BAM file and run samtools stats, flagstat and idxstats
// COPIED FROM nf-co/rnaseq
//

include { SORT_INDEX_STATS      } from './nf-core/samtools_sort_index_stats'

workflow SAMTOOLS_SORT_INDEX_STATS {
    take:
    ch_bam // channel: [ val(meta), [ bam ] ]

    main:

    ch_versions = Channel.empty()

    SORT_INDEX_STATS(
        ch_bam
    )
    ch_versions = ch_versions.mix(SORT_INDEX_STATS.out.versions)

    ADD_RG_AND_TAGS (
        SORT_INDEX_STATS.out.bam_index
        // other stuff
    )
    ch_version = ch_versions.mix(ADD_RG_TAGS.out.versions)


    emit:
    bam_index = ADD_RG_AND_TAGS.out.bam_index // channel: [ val(meta), [ bam ], [ bai ] ]
    stats     = SORT_INDEX_STATS.out.stats    // channel: [ val(meta), [ stats ] ]
    flagstat  = SORT_INDEX_STATS.out.flagstat // channel: [ val(meta), [ flagstat ] ]
    idxstats  = SORT_INDEX_STATS.out.idxstats // channel: [ val(meta), [ idxstats ] ]
    versions  = ch_versions                   // channel: [ versions.yml ]
}
