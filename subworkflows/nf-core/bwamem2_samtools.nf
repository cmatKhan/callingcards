//
// Index the reference genome and align reads
//

include { BWAMEM2_INDEX } from '../../modules/nf-core/modules/bwamem2/index/main'
include { BWAMEM2_MEM } from '../../modules/nf-core/modules/bwamem2/mem/main'
include { BAM_INDEX_SORT_RG } from './bam_index_sort_rg'

workflow BWAMEM2_SAMTOOLS {
    take:
    reads            // channel: [ val(meta), [ reads ] ]
    genome          // channel: file(ref_genome)

    main:

    ch_versions = Channel.empty()

    //
    // index the genome with bwamem2 index
    //
    BWAMEM2_INDEX ( genome )
    ch_versions = ch_versions.mix(BWAMEM2_INDEX.out.versions)

    //
    // Map reads with bwamem2 mem
    //
    sort_bam = false   // sort later
    BWAMEM2_MEM ( reads, BWAMEM2_INDEX.out.index, sort_bam )
    ch_versions = ch_versions.mix(BWAMEM2_MEM.out.versions)

    //
    // Add Read Group, Sort, index BAM file and run samtools stats, flagstat and idxstats
    //
    BAM_INDEX_SORT_RG (  BWAMEM2_MEM.out.bam )
    ch_versions = ch_versions.mix(BAM_INDEX_SORT_RG.out.versions)

    emit:
    bam            = BAM_INDEX_SORT_RG.out.bam      // channel: [ val(meta), [ bam ] ]
    stats          = BAM_INDEX_SORT_RG.out.stats    // channel: [ val(meta), [ stats ] ]
    flagstat       = BAM_INDEX_SORT_RG.out.flagstat // channel: [ val(meta), [ flagstat ] ]
    idxstats       = BAM_INDEX_SORT_RG.out.idxstats // channel: [ val(meta), [ idxstats ] ]

    versions       = ch_versions                    // channel: [ versions.yml ]
}
