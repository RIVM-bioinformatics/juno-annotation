#############################################################################
#####                       Annotation                                  #####
#############################################################################

rule annotation_prokka:
    input:
        fasta = OUT + "/circlator/{sample}/{sample}.fasta",
        tbl2asn = "tbl2asn"
    output:
        OUT + "/prokka/{sample}/{sample}.gbk"
    threads: config["threads"]["prokka"]
    resources: mem_mb=config["mem_mb"]["prokka"]
    conda:
        "../../envs/prokka.yaml"
    params:
        genus = lambda wildcards: SAMPLES[wildcards.sample]["Genus"],
        species = lambda wildcards: SAMPLES[wildcards.sample]["Species"],
        protein_db = config["protein_db"]
    log:
        OUT + "/log/prokka/{sample}.log"
    benchmark:
        OUT + "/log/benchmark/prokka_{sample}.txt"
    shell:
        """
output_dir={output}
sample_name=`basename ${{output_dir}}`
output_dir=`dirname ${{output_dir}}`

if [ {params.species} != "nan" ]; then
    prokka --outdir ${{output_dir}} --force \
    --genus {params.genus} \
    --species {params.species} \
    --prefix ${{sample_name%.gbk}} \
    --proteins {params.protein_db} \
    --cpus {threads} {input.fasta} &>> {log}
else
    prokka --outdir ${{output_dir}} --force \
    --genus {params.genus} \
    --prefix ${{sample_name%.gbk}} \
    --proteins {params.protein_db} \
    --cpus {threads} {input.fasta} &>> {log}
fi
        """