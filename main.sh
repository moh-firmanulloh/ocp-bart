#!/bin/bash
#
#
config_file="migrate.conf"
order="clusterrolebinding project image serviceaccount secret configmap rolebinding persistentvolumeclaim replicaset deployment replicationcontroller deploymentconfig cronjob statefulset service route horizontalpodautoscaler virtualservice destinationrule serviceentry envoyfilter"

if [[ "$#" -eq 13 ]];then
	script_mode=$1
	project_name=$2
	ocp_source="${3%/}"
	ocp_source_user=$4
	ocp_source_pass=$5
	ocp_target="${6%/}"
	ocp_target_user=$7
	ocp_target_pass=$8
	ocp_registry_source=$9
	ocp_registry_source_token=${10}
	ocp_registry_target=${11}
	ocp_registry_target_token=${12}
	base_dir=${13}
elif [[ ! -z "$config_file" && -f "$config_file" ]];then
	source "$config_file"
else
	missing=()
	[[ -z "$script_mode" ]] && missing+=("scriptMode")
	[[ -z "$project_name" ]] && missing+=("projectName")
	[[ -z "$ocp_source" ]] && missing+=("ocpSourceApiURL")
	[[ -z "$ocp_source_user" ]] && missing+=("ocpSourceUser")
	[[ -z "$ocp_source_pass" ]] && missing+=("ocpSourcePass")
	[[ -z "$ocp_target" ]] && missing+=("ocpTargetApiURL")
	[[ -z "$ocp_target_user" ]] && missing+=("ocpTargetUser")
	[[ -z "$ocp_target_pass" ]] && missing+=("ocpTargetPass")
	[[ -z "$ocp_registry_source" ]] && missing+=("ocpRegistrySource")
	[[ -z "$ocp_registry_source_token" ]] && missing+=("ocpTokenSource")
	[[ -z "$ocp_registry_target" ]] && missing+=("ocpRegistryTarget")
	[[ -z "$ocp_registry_target_token" ]] && missing+=("ocpTokenTarget")

	if [[ ${#missing[@]} -gt 0 ]]; then
		echo "Missing required variable(s): ${missing[*]}"
		echo "Usage: $0 scriptMode projectName ocpSourceApiURL ocpSourceUser ocpSourcePass ocpTargetApiURL ocpTargetUser ocpTargetPass ocpRegistrySource ocpTokenSource ocpRegistryTarget ocpTokenTarget baseDir"
        exit 1
	fi
fi

if [[ $script_mode == "backup" ]];then
	ocp_user=$ocp_source_user
	ocp_pass=$ocp_source_pass
	ocp_url=$ocp_source
elif [[ $script_mode == "restore" ]];then
	ocp_user=$ocp_target_user
	ocp_pass=$ocp_target_pass
	ocp_url=$ocp_target
fi

function construct_args() {
	local script=$1
	local usage_output required_args arg
	export BUILDING_ARGS=true
	usage_output=$(bash "$script" 2>&1 || true)
	unset BUILDING_ARGS
	read -r -a required_args <<<"$(echo "$usage_output" | cut -d" " -f2-)"
	args_to_pass=()
	for arg in "${required_args[@]}";do
		case "$arg" in
			projectName) args_to_pass+=("$project_name") ;;
			ocpApiURL) args_to_pass+=("$ocp_url") ;;
			ocpUser) args_to_pass+=("$ocp_user") ;;
			ocpPass) args_to_pass+=("$ocp_pass") ;;
			ocpSourceApiURL) args_to_pass+=("$ocp_source") ;;
			ocpTargetApiURL) args_to_pass+=("$ocp_target") ;;
			ocpSourceUser) args_to_pass+=("$ocp_source_user") ;;
			ocpTargetUser) args_to_pass+=("$ocp_target_user") ;;
			ocpSourcePass) args_to_pass+=("$ocp_source_pass") ;;
			ocpTargetPass) args_to_pass+=("$ocp_target_pass") ;;
			baseDir) args_to_pass+=("$base_dir") ;;
			ocpRegistrySource) args_to_pass+=("$ocp_registry_source") ;;
			ocpRegistryTarget) args_to_pass+=("$ocp_registry_target") ;;
			ocpTokenSource) args_to_pass+=("$ocp_registry_source_token") ;;
			ocpTokenTarget) args_to_pass+=("$ocp_registry_target_token") ;;
			clusterRoleBindingMigrate) args_to_pass+=("$clusterrolebinding_param") ;;
			projectMigrate) args_to_pass+=("$project_param") ;;
			imageMigrate) args_to_pass+=("$image_param") ;;
			serviceAccountMigrate) args_to_pass+=("$serviceaccount_param") ;;
			secretMigrate) args_to_pass+=("$secret_param") ;;
			configMapMigrate) args_to_pass+=("$configmap_param") ;;
			roleBindingMigrate) args_to_pass+=("$rolebinding_param") ;;
			pvcMigrate) args_to_pass+=("$persistentvolumeclaim_param") ;;
			replicaSetMigrate) args_to_pass+=("$replicaset_param") ;;
			deploymentMigrate) args_to_pass+=("$deployment_param") ;;
			rcMigrate) args_to_pass+=("$replicationcontroller_param") ;;
			deploymentConfigMigrate) args_to_pass+=("$deploymentconfig_param") ;;
			cronJobMigrate) args_to_pass+=("$cronjob_param") ;;
			stsMigrate) args_to_pass+=("$statefulset_param") ;;
			serviceMigrate) args_to_pass+=("$service_param") ;;
			routeMigrate) args_to_pass+=("$route_param") ;;
			removeTLS) args_to_pass+=("$remove_route_tls") ;;
			hpaMigrate) args_to_pass+=("$horizontalpodautoscaler_param") ;;
			virtualServiceMigrate) args_to_pass+=("$virtualservice_param") ;;
			destinationRuleMigrate) args_to_pass+=("$destinationrule_param") ;;
			serviceEntryMigrate) args_to_pass+=("$serviceentry_param") ;;
			envoyFilterMigrate) args_to_pass+=("$envoyfilter_param") ;;
			onlyHelm) args_to_pass+=("$only_helm") ;;
			patchGateway) args_to_pass+=("$patch_gateway") ;;
			newGateway) args_to_pass+=("$new_gateway") ;;
			newStorageClass) args_to_pass+=("$new_storageclass") ;;
			exportHelm) args_to_pass+=("$export_helm") ;;
		esac
	done
}

if [[ ! -z $projects ]];then
	for project_name in "${projects[@]}";do
		for scripts in $(echo "${order}");do
			script=$(echo "$script_mode-script/$script_mode-${scripts}.sh")
			construct_args $script
			if [[ $bypass ]];then
				if [[ $script_mode == "restore" ]];then
					printf 'Y\n' | bash "$script" "${args_to_pass[@]}"
				else
					bash "$script" "${args_to_pass[@]}"
				fi
			else
				bash "$script" "${args_to_pass[@]}"
			fi
		done
	done
else
	for scripts in $(echo "${order}");do
		script=$(echo "$script_mode-script/$script_mode-${scripts}.sh")
		construct_args $script
		if [[ $bypass ]];then
			if [[ $script_mode == "restore" ]];then
				printf 'Y\n' | bash "$script" "${args_to_pass[@]}"
			else
				bash "$script" "${args_to_pass[@]}"
			fi
		else
			bash "$script" "${args_to_pass[@]}"
		fi
	done
fi
