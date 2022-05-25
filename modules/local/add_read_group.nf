process ADD_READ_GROUP {

    tag "$meta.id"

    conda (params.enable_conda ? "conda-forge::pysam=0.17.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pysam%3A0.17.0--py39h20405f9_1' :
        'quay.io/biocontainers/pysam' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*tagged.bam"),path("*tagged.bam.bai")  , emit: bam
    path("*tagged.bam.bai")                                       , emit: bai
    path  "versions.yml"                                          , emit: versions

    script: // see nf-core-callingcards/bin/add_read_group_to_bam.py
    """
    add_read_group.py \\
        $bam \\
        "test_tagged.bam" \\
        $params.barcode_length \\
        10


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pysam: \$(pip freeze | grep pysam | sed 's/pysam==//g')
    END_VERSIONS

    """
}

// ${bam/%\.bam/_tagged.bam} \\
        // $task.cpus
