#############################################################################
#####          Fix starting point of chromosome and plasmids            #####
#############################################################################

rule fixstart_circlator:
    input:
        OUT + "/filtered_contigs/{sample}.fasta"
    output:
        OUT + "/circlator/{sample}/{sample}.fasta",
        temp(OUT + "/circlator/{sample}/{sample}.prodigal.for_prodigal.fa"),
        temp(OUT + "/circlator/{sample}/{sample}.prodigal.prodigal.gff"),
        temp(OUT + "/circlator/{sample}/{sample}.promer.promer"),
        temp(OUT + "/circlator/{sample}/{sample}.promer.contigs_with_ends.fa"),
        temp(OUT + "/circlator/{sample}/{sample}.log"),
        temp(OUT + "/circlator/{sample}/{sample}.detailed.log")
    conda:
        "../../envs/circlator.yaml"
    threads: config["threads"]["circlator"]
    params:
        OUT + "/circlator/{sample}/{sample}"
    log:
        OUT + "/log/circlator/{sample}.log"
    benchmark:
        OUT + "/log/benchmark/circlator_{sample}.txt"
    shell:
        """
circlator fixstart {input} {params} &> {log}
        """
