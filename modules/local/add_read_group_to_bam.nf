process ADD_READ_GROUP {
    tag "$bam"

    conda (params.enable_conda ? "conda-forge::pysam=0.17.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pysam%3A0.17.0--py39h20405f9_1' :
        'quay.io/biocontainers/pysam' }"

    input:
    path bam

    output:
    path '*.bam'       , emit: csv
    path "versions.yml", emit: versions

    script: // see nf-core/callingcards/bin/add_read_group_to_bam.py
    """
    add_read_group_to_bam.py \\
        $bam \\
        ${bam/%\.bam/_tagged.bam}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pysam: \$(pip freeze | grep pysam | sed 's/pysam==//g')
    END_VERSIONS
    """
}
