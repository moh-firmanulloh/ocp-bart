#!/bin/bash
#
#
order=(clusterrolebinding project image serviceaccount secret configmap rolebinding persistentvolumeclaim replicaset deployment replicationcontroller deploymentconfig cronjob statefulset service route horizontalpodautoscaler virtualservice destinationrule serviceentry envoyfilter)

temp_work_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$config_file" ]];then
        echo "Finding migrate.conf"
        temp_config_file="$temp_work_dir/migrate.conf"
        if [[ -f $temp_config_file ]];then
                echo "migrate.conf found. Using configuration files as reference"
                config_file=$temp_config_file
                source $config_file
        else
                unset temp_config_file
                echo "No migrate.conf found"
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

function pre_flight() {
	echo "Pre-flight checks from main. All variables will be examined."
	echo "Finding pre-flight.sh"
	temp_pre_flight="$temp_work_dir/pre-flight.sh"
	if [[ -f $temp_pre_flight ]];then
	        pre_flight=$temp_pre_flight
	        echo "pre-flight.sh found."
	else
	        unset temp_pre_flight
	        echo "No pre-flight.sh found"
	        exit 1
	fi
	for scripts in "${order[@]}";do
		script=$(echo "$script_mode-${scripts}.sh")
        	param_var="${scripts}_param"
		if [[ -z "${!param_var+x}" ]];then
			echo "ERROR: Missing parameter: $param_var in migrate.conf"
			echo "Please set it to true or false."
			exit 1
		fi
	        migrate_param=${!param_var:-}
	        if [[ "${migrate_param}" == "true" ]];then
			echo "Running pre-flight check for $script"
		        bash $pre_flight $script $config_file && echo "All is well" || {
		                echo "Pre-flight failed. Aborting."
		                exit 1
		        }
		elif [[ "${migrate_param}" == "false" ]];then
			echo "Skipping pre-flight check for $script (explicitly disabled. $param_var=$migrate_param)"
		else
			echo "ERROR: Invalid value for $param_var: '$migrate_param'"
			echo "Must be exactly true or false."
    			exit 1
		fi
	done
}

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

pre_flight

if [[ ! -z $projects ]];then
export RUN_FROM_MAIN=true
	for project_name in "${projects[@]}";do
		for scripts in $(echo "${order[@]}");do
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
	for scripts in $(echo "${order[@]}");do
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
unset RUN_FROM_MAIN
fi

