#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Deploy + (re)start the ARDY Director control service on the ARDY host.
set -euo pipefail
HOST="${ARDY_HOST:-192.168.0.136}"
USER="${ARDY_USER:-sophiacore}"
PASS="${ARDY_PASS:-Elyanlabs12@}"
PORT="${DIRECTOR_PORT:-9600}"
SSH="sshpass -p $PASS ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no $USER@$HOST"
SCP="sshpass -p $PASS scp -o StrictHostKeyChecking=no -o PubkeyAuthentication=no"

echo "[deploy] copying service to $HOST"
$SSH 'mkdir -p ~/ardy-director/director_service'
$SCP director_service/service.py "$USER@$HOST:~/ardy-director/director_service/service.py"

echo "[deploy] ensuring service deps in ardy venv"
$SSH 'cd ~/ardy && source venv/bin/activate && pip install -q "fastapi>=0.110" "uvicorn>=0.27" "pydantic>=2" 2>&1 | tail -1 || true'

echo "[deploy] (re)starting service on :$PORT"
$SSH "pkill -f director_service/service.py || true; sleep 2; cd ~/ardy && source venv/bin/activate && \
  export CUDA_VISIBLE_DEVICES=0 PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True HF_TOKEN=\$(cat ~/.cache/huggingface/token) \
  DIRECTOR_PORT=$PORT && setsid bash -c 'nohup python ~/ardy-director/director_service/service.py >> ~/ardy_director.log 2>&1' < /dev/null & disown" || true

echo "[deploy] waiting for health..."
for i in $(seq 1 20); do
  if $SSH "curl -s --max-time 4 http://localhost:$PORT/health" 2>/dev/null | grep -q '"ok":true'; then
    echo "[deploy] UP"; $SSH "curl -s http://localhost:$PORT/health"; exit 0
  fi
  sleep 5
done
echo "[deploy] service did not come up; check ~/ardy_director.log on $HOST"; exit 1
