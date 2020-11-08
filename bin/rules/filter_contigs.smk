#############################################################################
#####          Fix starting point of chromosome and plasmids            #####
#############################################################################

rule filter_contigs:
    input:
        lambda wildcards: SAMPLES[wildcards.sample]["fasta_file"]
    output:
        OUT + "/filtered_contigs/{sample}.fasta"
    log:
        OUT + "/log/filtering/{sample}.log"
    benchmark:
        OUT + "/log/benchmark/filtering_{sample}.txt"
    shell:
        """
perl bin/filter_contigs.pl 200 {input} > {output} 2> {log}
        """
