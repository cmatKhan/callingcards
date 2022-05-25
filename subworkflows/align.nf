//
// Align reads to a reference genome
// note that this can be parameterized -- could put $param.aligner
// in the include ... from ... path below
//

include { ALIGNER } from '.nf-core/modules/bwamem2/index/main'

workflow ALIGN {
    take:
    reads            // channel: [ val(meta), [ reads ] ]
    genome          // channel: file(ref_genome)

    main:

    ch_versions = Channel.empty()

    ALIGNER (
        reads,
        genome
    )
    ch_versions = ch_versions.mix(ALIGNER.out.versions)

    emit:
    bam       = ALIGNER.out.bam  // channel: [ val(meta), [ bam ] ]
    versions  = ch_versions      // channel: [ versions.yml ]
}
