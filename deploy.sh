#!/bin/bash
set -e

DOCKER_IMAGE="stepan106/logger-app-python:latest"

echo "==== Развертывание распределенной системы логирования ===="

echo "1. Сборка Docker образа и отправка в minikube docker-registry..."
eval $(minikube docker-env)
docker build -t $DOCKER_IMAGE .
# Для minikube достаточно build, push скрипт можно не делать!

kubectl apply -f k8s/config.yaml
kubectl apply -f k8s/pod.yaml

kubectl wait --for=condition=Ready pod/app-pod --timeout=60s

kubectl port-forward pod/app-pod 8080:8080 &
PF_PID=$!
sleep 2
echo "==== Smoke test ====="
curl http://localhost:8080/
curl http://localhost:8080/status
curl -X POST http://localhost:8080/log -d '{"message": "Test log"}' -H "Content-Type: application/json"
curl http://localhost:8080/logs
kill $PF_PID || true
echo "====================="

kubectl apply -f k8s/deployment.yaml
kubectl rollout status deployment/app-deployment

kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/daemonset.yaml
kubectl apply -f k8s/cronjob.yaml

# ==== ISTIO ====

if ! kubectl get namespace istio-system > /dev/null 2>&1; then
  echo "11. Установка Istio Service Mesh (демо профиль)..."
  curl -L https://istio.io/downloadIstio | sh -
  cd istio-*
  export PATH=$PWD/bin:$PATH
  istioctl install --set profile=demo -y
  cd ..
fi

kubectl label namespace default istio-injection=enabled --overwrite

kubectl rollout restart deployment/app-deployment
kubectl rollout status deployment/app-deployment

kubectl apply -f k8s/istio/gateway.yaml
kubectl apply -f k8s/istio/virtualservice.yaml
kubectl apply -f k8s/istio/destinationrule-app.yaml

# ==== PROMETHEUS + MONITORING ====

NAMESPACE=monitoring
RELEASE=prom-stack

set +e
HELM_STATUS=$(helm status $RELEASE -n $NAMESPACE 2>&1)
set -e

if echo "$HELM_STATUS" | grep -q 'STATUS: failed'; then
  echo "Обнаружен неудачный релиз prom-stack, удаляю..."
  helm uninstall $RELEASE -n $NAMESPACE || true
  sleep 10
fi

if ! helm list -n $NAMESPACE 2>/dev/null | grep $RELEASE; then
  echo "15. Установка kube-prometheus-stack через Helm..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
  helm repo update
  kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
  helm install $RELEASE prometheus-community/kube-prometheus-stack \
    -n $NAMESPACE --set prometheus.prometheusSpec.maximumStartupDurationSeconds=300
  echo "Ожидание запуска Prometheus..."
  kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus -n $NAMESPACE --timeout=180s || true
else
  echo "prom-stack уже установлен."
fi

kubectl apply -f k8s/app-metrics-service.yaml
kubectl apply -f k8s/app-metrics-servicemonitor.yaml

echo "==== Система успешно развернута! ===="
echo
echo "1. Для доступа к приложению через Istio Ingress выполните (в отдельном окне):"
echo "   minikube tunnel"
echo "   curl http://127.0.0.1/"
echo "   curl -X POST http://127.0.0.1/log -d '{\"message\":\"Test attempt\"}' -H 'Content-Type: application/json'"
echo
echo "2. Для доступа к Prometheus UI (ещё один терминал):"
echo "   kubectl port-forward -n monitoring svc/prom-stack-kube-prometheus-prometheus 9090:9090"
echo "   Перейти в браузере: http://localhost:9090"
echo
echo "3. Для доступа к Grafana (ещё один терминал):"
echo "   kubectl port-forward -n monitoring svc/prom-stack-grafana 3000:80"
echo "   Перейти в браузере: http://localhost:3000"
echo "   (Пароль можно узнать командой: kubectl get secret -n monitoring prom-stack-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode)"
echo
echo "Проверь метрики istio_requests_total, log_requests_total и другие!"
echo
