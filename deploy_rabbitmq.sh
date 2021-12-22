#!/bin/bash

RABBITMQ_REGISTRY = 'bitnami/rabbitmq'
CONSUMER_REGISTRY = 'alexfersh/consumer'
PRODUCER_REGISTRY = 'alexfersh/producer'
HELM_REPO = 'https://charts.bitnami.com/bitnami'

helm repo add bitnami $HELM_REPO
helm repo update
export namespace=`cat ./helm/values.yaml | grep -w namespace: | tr '\t\n' ' ' | tr -s ' ' | cut -d ' ' -f2`
export releasename=`cat ./helm/values.yaml | grep -w releasename: | tr '\t\n' ' ' | tr -s ' ' | cut -d ' ' -f2`

check_namespace=`kubectl get namespace | grep -w $namespace | tr '\t\n' ' ' | tr -s ' ' | cut -d ' ' -f1`
if [[ `kubectl get namespace | grep -w $namespace | tr '\t\n' ' ' | tr -s ' ' | cut -d ' ' -f1` != $namespace ]]; then
	kubectl create $namespace
fi

check_release=`helm --namespace=$namespace list | grep -w $releasename | tr '\t\n' ' ' | tr -s ' ' | cut -d ' ' -f1`
if [[ `helm --namespace=$namespace list | grep -w $releasename | tr '\t\n' ' ' | tr -s ' ' | cut -d ' ' -f1` != $releasename ]]; then

	helm upgrade $releasename $RABBITMQ_REGISTRY -f rabbitmq-values.yaml --install --force --namespace=$namespace

	export cluster_ip=`kubectl --namespace $namespace get svc | grep -w $releasename | grep -v headless | tr '\t\n' ' ' | tr -s ' ' | cut -d ' ' -f3`
	export podname=`kubectl --namespace $namespace get pods | grep -w rabbitmq-0 | cut -d ' ' -f1`
	export rabbitmq_username=`kubectl --namespace $namespace describe pods $podname | grep -w RABBITMQ_USERNAME: | tr '\t\n' ' ' | tr -s ' ' | cut -d ' ' -f3`
	export rabbitmq_secret=`kubectl --namespace $namespace describe pods $podname | grep -w RABBITMQ_PASSWORD: | tr '\t\n' ' ' | tr -s ' ' | tr -d "<'>" | cut -d ':' -f2 | cut -d ' ' -f9`
	export rabbitmq_password=`kubectl --namespace $namespace get secret $rabbitmq_secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d`

	sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/producer-deployment.yaml
	sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/consumer-deployment.yaml
	sed -i "s/('guest', 'guest')/('$rabbitmq_username', '$rabbitmq_password')/" ./consumer/consumer.py
	sed -i "s/('guest', 'guest')/('$rabbitmq_username', '$rabbitmq_password')/" ./producer/producer.py

else
	export podname=`kubectl --namespace $namespace get pods | grep -w rabbitmq-0 | cut -d ' ' -f1`
	export rabbitmq_secret=`kubectl --namespace $namespace describe pods $podname | grep -w RABBITMQ_PASSWORD: | tr '\t\n' ' ' | tr -s ' ' | tr -d "<'>" | cut -d ':' -f2 | cut -d ' ' -f9`
	export RABBITMQ_PASSWORD=$(kubectl --namespace $namespace get secret $rabbitmq_secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d)
	export RABBITMQ_ERLANG_COOKIE=$(kubectl --namespace $namespace get secret $rabbitmq_secret -o jsonpath="{.data.rabbitmq-erlang-cookie}" | base64 -d)

	helm upgrade $releasename $RABBITMQ_REGISTRY -f rabbitmq-values.yaml --install --force --namespace=$namespace --set auth.password=$RABBITMQ_PASSWORD --set auth.erlangCookie=$RABBITMQ_ERLANG_COOKIE

	export cluster_ip=`kubectl --namespace $namespace get svc | grep -w $releasename | grep -v headless | tr '\t\n' ' ' | tr -s ' ' | cut -d ' ' -f3`
	export podname=`kubectl --namespace $namespace get pods | grep -w rabbitmq-0 | cut -d ' ' -f1`
	export rabbitmq_username=`kubectl --namespace $namespace describe pods $podname | grep -w RABBITMQ_USERNAME: | tr '\t\n' ' ' | tr -s ' ' | cut -d ' ' -f3`
	export rabbitmq_secret=`kubectl --namespace $namespace describe pods $podname | grep -w RABBITMQ_PASSWORD: | tr '\t\n' ' ' | tr -s ' ' | tr -d "<'>" | cut -d ':' -f2 | cut -d ' ' -f9`
	export rabbitmq_password=`kubectl --namespace $namespace get secret $rabbitmq_secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d`

	sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/producer-deployment.yaml
	sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/consumer-deployment.yaml
	sed -i "s/('guest', 'guest')/('$rabbitmq_username', '$rabbitmq_password')/" ./consumer/consumer.py
	sed -i "s/('guest', 'guest')/('$rabbitmq_username', '$rabbitmq_password')/" ./producer/producer.py

fi
