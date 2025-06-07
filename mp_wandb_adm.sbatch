#!/bin/bash
#SBATCH --ntasks=1
#SBATCH -A zhangmlgroup
#SBATCH --mem=64G
#SBATCH -p gpu

#SBATCH --gres=gpu:a100:2
#SBATCH --cpus-per-task=32
#SBATCH --time=1-02:00:00

# 设置环境
module load miniforge
source activate beep-env
chmod +x /scratch/nkw3mr/sdoh_clinical_outcome_prediction/BEEP/Strucure-Awared-Clinical-Note-Processing/outcome-prediction/run_outcome_prediction_adm.py

# 从命令行获取变量，或使用默认值
strategy=${strategy:-'average'}
batch_size=${batch_size:-8}
num_top_docs=${num_top_docs:-10}
num_heads=${num_heads:-2}
seed=${seed:-0}
use_section=${use_section:-false}
init_model=${init_model:-"microsoft/BiomedNLP-BiomedBERT-base-uncased-abstract-fulltext"}  # 新增的变量
epochs=${epochs:-5}
lr=${lr:-2e-5}
job_id=${SLURM_JOB_ID}
dataset=${dataset:-"mimic_iii"}
use_long=${use_long:-false}
module_type=${module_type:-"full"}
delta=${delta:-0.1}
orth_weight=${orth_weight:-0.1}
reduced_dimension=${reduced_dimension:-256}
job_name="job_${job_id}"
accumulation_steps=${accumulation_steps:-12}
num_experts=${num_experts:-2}
top_k=${top_k:-0}
do_dimension_reduction=${do_dimension_reduction:-false}


if [ "$use_section" = "true" ]; then
    out_dir="/scratch/nkw3mr/sdoh_clinical_outcome_prediction/BEEP/Strucure-Awared-Clinical-Note-Processing/output/mp/dataset_${dataset}/section_based/job_${job_id}"
    log_dir="logs/mp/dataset_${dataset}/section_based/seed_${seed}/lr_${lr}/"
    section_flag="--section_segment"
    train_path="/scratch/nkw3mr/sdoh_clinical_outcome_prediction/clinical-outcome-prediction/tasks/mimic_iii_data/mp/sections/train.json"
    dev_path="/scratch/nkw3mr/sdoh_clinical_outcome_prediction/clinical-outcome-prediction/tasks/mimic_iii_data/mp/sections/val.json"
    test_path="/scratch/nkw3mr/sdoh_clinical_outcome_prediction/clinical-outcome-prediction/tasks/mimic_iii_data/mp/sections/test.json"
    longmodel_flag=""
    if [ -z "$do_dimension_reduction" ] || [ "$do_dimension_reduction" = "false" ]; then
        do_dimension_reduction_flag=""
    else
        do_dimension_reduction_flag="--do_dimension_reduction"
    fi
else
    do_dimension_reduction_flag=""
    section_flag=""
    train_path="/scratch/nkw3mr/sdoh_clinical_outcome_prediction/clinical-outcome-prediction/tasks/mimic_iii_data/mp/filtered/train.csv"
    dev_path="/scratch/nkw3mr/sdoh_clinical_outcome_prediction/clinical-outcome-prediction/tasks/mimic_iii_data/mp/filtered/val.csv"
    test_path="/scratch/nkw3mr/sdoh_clinical_outcome_prediction/clinical-outcome-prediction/tasks/mimic_iii_data/mp/filtered/test.csv"
    if [ "$use_long" = "true" ]; then
        out_dir="/scratch/nkw3mr/sdoh_clinical_outcome_prediction/BEEP/Strucure-Awared-Clinical-Note-Processing/output/mp/dataset_${dataset}/${init_model}/long/seed_${seed}/lr_${lr}/job_${job_id}"
        log_dir="logs/mp/dataset_${dataset}/${init_model}/long/seed_${seed}/lr_${lr}"
        longmodel_dir="${out_dir}/longmodel_dir"
        longmodel_flag="--longmodel_dir ${longmodel_dir}"
    else
        out_dir="/scratch/nkw3mr/sdoh_clinical_outcome_prediction/BEEP/Strucure-Awared-Clinical-Note-Processing/output/mp/dataset_${dataset}/${init_model}/raw/seed_${seed}/lr_${lr}/job_${job_id}"
        log_dir="logs/mp/dataset_${dataset}/${init_model}/raw/seed_${seed}/lr_${lr}"
        longmodel_flag=""
    fi
fi


mkdir -p $log_dir
# 使用 srun 指定输出和错误日志文件路径
srun --output=${log_dir}/${job_name}-%j.out \
     --error=${log_dir}/${job_name}-%j.err \
     ~/.conda/envs/beep-env/bin/python /scratch/nkw3mr/sdoh_clinical_outcome_prediction/BEEP/Strucure-Awared-Clinical-Note-Processing/outcome-prediction/run_outcome_prediction_adm.py \
     --train_path $train_path \
     --dev_path $dev_path \
     --test_path $test_path \
     --out_dir $out_dir \
     --lr $lr \
     $longmodel_flag \
     --dump_test_preds \
     --warmup_steps 5000 \
     --init_model $init_model --outcome mp --do_train --do_test \
     --batch_size $batch_size \
     --seed $seed  $section_flag --epochs $epochs \
     --reduced_dimension $reduced_dimension \
     --orth_weight $orth_weight --delta $delta --module_type $module_type \
     --accumulation_steps $accumulation_steps --num_experts $num_experts --top_k $top_k --num_heads $num_heads \
     $do_dimension_reduction_flag



conda deactivate


