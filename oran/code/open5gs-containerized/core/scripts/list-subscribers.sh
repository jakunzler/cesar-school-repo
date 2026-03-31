#!/bin/bash
# Lista assinantes cadastrados no MongoDB (open5gs.subscribers).
# Isso é o perfil no core (quem pode registrar), não o estado em tempo real do AMF.

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if ! docker compose ps | grep -q "mongodb.*Up"; then
    echo "ERRO: MongoDB não está rodando (subir o core antes)."
    exit 1
fi

echo "=========================================="
echo "Assinantes no MongoDB (open5gs.subscribers)"
echo "=========================================="
docker compose exec -T mongodb mongosh open5gs --quiet --eval '
const n = db.subscribers.countDocuments({});
print("Total de documentos:", n);
print("");
db.subscribers.find({}, { imsi: 1, msisdn: 1, _id: 0 }).forEach(function (d) { printjson(d); });
'
