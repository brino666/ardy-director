#!/bin/bash
# runs ON the ardy host; started detached
cd ~/ardy || exit 1
source venv/bin/activate
export CUDA_VISIBLE_DEVICES=0
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export HF_TOKEN=$(cat ~/.cache/huggingface/token)
export DIRECTOR_PORT=9600
exec python ~/ardy-director/director_service/service.py >> ~/ardy_director.log 2>&1
