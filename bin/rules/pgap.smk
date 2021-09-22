#############################################################################
#####                       Annotation                                  #####
#############################################################################

rule annotation_pgap:
    input:
        fasta = OUT + "/circlator/{sample}/{sample}.fasta"
    output:
        input_yaml = temp(OUT + "/circlator/{sample}/{sample}_input.yaml"),
        submol_yaml = temp(OUT + "/circlator/{sample}/{sample}_submol.yaml"),
        gbk_output = OUT + "/pgap/{sample}/{sample}.gbk",
        faa_output = OUT + "/pgap/{sample}/{sample}.faa",
        fna_output = OUT + "/pgap/{sample}/{sample}.fna",
        sqn_output = OUT + "/pgap/{sample}/{sample}.sqn",
        gff_output = OUT + "/pgap/{sample}/{sample}.gff"
    threads: config["threads"]["pgap"]
    resources: mem_mb=config["mem_mb"]["pgap"]
    params:
        genus = lambda wildcards: SAMPLES[wildcards.sample]["genus"],
        species = lambda wildcards: SAMPLES[wildcards.sample]["species"],
        temp_output = lambda wildcards: OUT + "/pgap/" + str(wildcards.sample) + "_1"
    log:
        OUT + "/log/pgap/{sample}.log"
    benchmark:
        OUT + "/log/benchmark/pgap_{sample}"
    shell:
        """
input_file={input}
input_file=`basename ${{input_file}}`

python bin/make_input_pgap.py --fasta_file ${{input_file}} \
    --genus {params.genus} \
    --species {params.species} \
    --input_file {output.input_yaml} \
    --submol_file {output.submol_yaml} &> {log}

python bin/pgap.py -D /usr/bin/singularity --no-self-update -o {params.temp_output} -c {threads} {output.input_yaml} &>> {log}

mv {params.temp_output}/annot.gbk {output.gbk_output}
mv {params.temp_output}/annot.faa {output.faa_output}
mv {params.temp_output}/annot.fna {output.fna_output}
mv {params.temp_output}/annot.gff {output.gff_output}
mv {params.temp_output}/annot.sqn {output.sqn_output}
rm -r {params.temp_output}
        """