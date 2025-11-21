#!/bin/bash
#
#
config_file=$2

source "$config_file"

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
	script_name=$1
	script="$script_mode-script/$1"
	object=$(echo $script_name | cut -d"-" -f2 | cut -d"." -f1)
	param_var="${object}_param"
	if [[ -z "${!param_var+x}" ]];then
		echo "ERROR: Missing parameter: $param_var in migrate.conf"
		echo "Please set it to true or false."
		exit 1
	fi
	migrate_param=${!param_var}
	if [[ "${migrate_param:-}" == "true" ]];then
		echo "Evaluating variables required for $script_name"
	        local usage_output required_args arg
	        export BUILDING_ARGS=true
	        usage_output=$(bash "$script" 2>&1 || true)
	        unset BUILDING_ARGS
	        read -r -a required_args <<<"$(echo "$usage_output" | cut -d" " -f2-)"
	        args_to_pass=()
		missing=()
	        for arg in "${required_args[@]}";do
	                case "$arg" in
	                        projectName)
					if [[ ! -v projects ]];then
						missing+=("project_name")
					fi
					;;
	                        ocpApiURL) 
					if [[ ! -v ocp_url ]];then
					     missing+=("ocp_url")
					fi   
					;;
	                        ocpUser) 
					if [[ ! -v ocp_user ]];then
					     missing+=("ocp_user")
					fi   
					;;
	                        ocpPass) 
					if [[ ! -v ocp_pass ]];then
						missing+=("ocp_pass")
					fi
					;;
	                        ocpSourceApiURL) 
					if [[ ! -v ocp_source ]];then
						missing+=("ocp_source")
					fi	
					;;
	                        ocpTargetApiURL) 
					if [[ ! -v ocp_target ]];then
						missing+=("ocp_target")
					fi
					;;
	                        ocpSourceUser) 
					if [[ ! -v ocp_source_user ]];then
						missing+=("ocp_source_user")
					fi
					;;
	                        ocpTargetUser) 
					if [[ ! -v ocp_target_user ]];then
						missing+=("ocp_target_user")
					fi
					;;
	                        ocpSourcePass) 
					if [[ ! -v ocp_source_pass ]];then
						missing+=("ocp_source_pass")
					fi	
					;;
	                        ocpTargetPass) 
					if [[ ! -v ocp_target_pass ]];then
						missing+=("ocp_target_pass")
					fi
					;;
	                        baseDir) 
					if [[ ! -v base_dir ]];then
						missing+=("base_dir")	
					fi
					;;
	                        ocpRegistrySource) 
					if [[ ! -v ocp_registry_source ]];then
						missing+=("ocp_registry_source")
					fi
					;;
	                        ocpRegistryTarget) 
					if [[ ! -v ocp_registry_target ]];then
						missing+=("ocp_registry_target")
					fi
					;;
	                        ocpTokenSource) 
					if [[ ! -v ocp_registry_source_token ]];then
						missing+=("ocp_registry_source_token")
					fi
					;;
	                        ocpTokenTarget) 
					if [[ ! -v ocp_registry_target_token ]];then
						missing+=("ocp_registry_target_token")
					fi
					;;
	                        clusterRoleBindingMigrate) 
					if [[ ! -v clusterrolebinding_param ]];then
						missing+=("clusterrolebinding_param")
					fi
					;;
	                        projectMigrate) 
					if [[ ! -v project_param ]];then
						missing+=("project_param")
					fi
					;;
	                        imageMigrate) 
					if [[ ! -v image_param ]];then
						missing+=("image_param")
					fi
					;;
	                        serviceAccountMigrate) 
					if [[ ! -v serviceaccount_param ]];then
						missing+=("serviceaccount_param") 
					fi
					;;
	                        secretMigrate) 
					if [[ ! -v secret_param ]];then
						missing+=("secret_param") 
					fi
					;;
	                        configMapMigrate) 
					if [[ ! -v configmap_param ]];then
						missing+=("configmap_param") 
					fi
					;;
	                        roleBindingMigrate) 
					if [[ ! -v rolebinding_param ]];then
						missing+=("rolebinding_param") 
					fi
					;;
	                        pvcMigrate) 
					if [[ ! -v persistentvolumeclaim_param ]];then
						missing+=("persistentvolumeclaim_param")
					fi
					;;
	                        replicaSetMigrate) 
					if [[ ! -v replicaset_param ]];then
					       	missing+=("replicaset_param") 
					fi
					;;
	                        deploymentMigrate) 
					if [[ ! -v deployment_param ]];then
						missing+=("deployment_param") 
					fi
					;;
	                        rcMigrate) 
					if [[ ! -v replicationcontroller_param ]];then
						missing+=("replicationcontroller_param") 
					fi
					;;
	                        deploymentConfigMigrate) 
					if [[ ! -v deploymentconfig_param ]];then
						missing+=("deploymentconfig_param") 
					fi
					;;
	                        cronJobMigrate) 
					if [[ ! -v cronjob_param ]];then
						missing+=("cronjob_param") 
					fi
					;;
	                        stsMigrate) 
					if [[ ! -v statefulset_param ]];then
						missing+=("statefulset_param") 
					fi
					;;
	                        serviceMigrate) 
					if [[ ! -v service_param ]];then
						missing+=("service_param")
					fi
					;;
	                        routeMigrate) 
					if [[ ! -v route_param ]];then
						missing+=("route_param") 
					fi
					;;
	                        removeTLS) 
					if [[ ! -v remove_route_tls ]];then
						missing+=("remove_route_tls") 
					fi
					;;
	                        hpaMigrate) 
					if [[ ! -v horizontalpodautoscaler_param ]];then
						missing+=("horizontalpodautoscaler_param") 
					fi
					;;
	                        virtualServiceMigrate) 
					if [[ ! -v virtualservice_param ]];then
						missing+=("virtualservice_param") 
					fi
					;;
	                        destinationRuleMigrate) 
					if [[ ! -v destinationrule_param ]];then
						missing+=("destinationrule_param") 
					fi
					;;
	                        serviceEntryMigrate) 
					if [[ ! -v serviceentry_param ]];then
						missing+=("serviceentry_param") 
					fi
					;;
	                        envoyFilterMigrate) 
					if [[ ! -v envoyfilter_param ]];then
						missing+=("envoyfilter_param") 
					fi
					;;
	                        onlyHelm) 
					if [[ ! -v only_helm ]];then
						missing+=("only_helm") 
					fi
					;;
	                        patchGateway) 
					if [[ ! -v patch_gateway ]];then
						missing+=("patch_gateway") 
					fi
					;;
	                        newGateway) 
					if [[ ! -v new_gateway ]];then
						missing+=("new_gateway") 
					fi
					;;
	                        newStorageClass) 
					if [[ ! -v new_storageclass ]];then
						missing+=("new_storageclass") 
					fi
					;;
	                        exportHelm) 
					if [[ ! -v export_helm ]];then
						missing+=("export_helm") 
					fi
					;;
	                esac
	        done
		if [[ "${#missing[@]}" -gt 0 ]];then
			echo "Missing variable(s): ${missing[*]}"
			echo "Check your config file"
			exit 1
		fi
	elif [[ "${migrate_param}" == "false" ]];then
		echo "Skipping variables check as $param_var is set to $migrate_param"
	else
		echo "ERROR: $param_var must be either true or false, not '$migrate_param'"
    		exit 1
	fi

}

pre_flight $1
