#!/bin/bash
#
#
obj_target="secret"
export_helm=false
exclude_pattern="builder-token|builder-dockercfg|default-dockercfg|default-token|deployer-dockercfg|deployer-token|istio"
GREEN='\033[0;32m'
NC='\033[0m'
config_file="/home/thinkbook/ocp-bart/ocp-bart/migrate.conf"

if [[ "$#" -eq 9 ]];then
        project_name=$1
        ocp_source="${2%/}"
        ocp_source_user=$3
        ocp_source_pass=$4
        ocp_target="${5%/}"
        ocp_target_user=$6
        ocp_target_pass=$7
        secret_param=$8
        base_dir=${9%/}
elif [[ $BUILDING_ARGS ]];then
	echo "$0 projectName ocpSourceApiURL ocpSourceUser ocpSourcePass ocpTargetApiURL ocpTargetUser ocpTargetPass secretMigrate baseDir"
	exit 0
elif [[ ! -z "$config_file" && -f "$config_file" ]];then
        source "$config_file"
else
        echo "Define \$config_file or"
	echo "Usage: $0 projectName ocpSourceApiURL ocpSourceUser ocpSourcePass ocpTargetApiURL ocpTargetUser ocpTargetPass secretMigrate baseDir"
	exit 1
fi

work_dir=$(echo $base_dir/backup/$project_name/$obj_target)
kube_config_source="${base_dir}/.backup-kubeconfig"
kube_config_target="${base_dir}/.restore-kubeconfig"

echo "Source: $ocp_source"
echo "Target: $ocp_target"

function verify() {
	project_name=$1
	echo "Checking $obj_target $project_name"
	readarray -t obj_res < <(oc --kubeconfig $kube_config_source get $obj_target -n $project_name --no-headers | egrep -v $(echo $exclude_pattern) | awk '{print $1}')
	if [[ "${#obj_res[@]}" -ne 0 ]];then
		for resource in "${obj_res[@]}";do
			helm_label=$(oc --kubeconfig $kube_config_source get $obj_target $resource -n $project_name -ojson | jq -r '.metadata.labels.owner')
			secret_type=$(oc --kubeconfig $kube_config_source get $obj_target $resource -n $project_name -ojson | jq -r '.type')
			secret_ownerref=$(oc --kubeconfig $kube_config_source get $obj_target $resource -n $project_name -ojson | jq -r '.metadata.ownerReferences[0].name')
			if [[ $helm_label != "Helm" || $helm_label != "helm" || $secret_type != "helm.sh/release.v1" && $export_helm == "false" ]];then
				echo "Checking $obj_target: $resource"
				source_hash=$(oc --kubeconfig $kube_config_source get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .status)' | sha256sum | awk '{print $1}')
				target_hash=$(oc --kubeconfig $kube_config_target get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .status)' | sha256sum | awk '{print $1}')
	                        if [[ $target_hash != $source_hash ]];then
					if [[ $secret_type == "kubernetes.io/dockercfg" ]];then
						echo -e "$obj_target: $resource ${RED}does not match${NC}. Expected due to pull secret. Type: $secret_type. OwnerReferences: $secret_ownerref"
					else
		                                echo -e "$obj_target: $resource ${RED}does not match${NC}"
					fi
	                        else
	                                echo -e "$obj_target: $resource ${GREEN}match${NC}"
	                        fi

			elif [[ $export_helm == "true" ]];then
				echo "Checking$obj_target: $resource"
				source_hash=$(oc --kubeconfig $kube_config_source get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .status)' | sha256sum)
				target_hash=$(oc --kubeconfig $kube_config_target get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .status)' | sha256sum)
	                        if [[ $target_hash != $source_hash ]];then
	                                echo -e "$obj_target: $resource ${RED}does not match${NC}"
        	                else
                	                echo -e "$obj_target: $resource ${GREEN}match${NC}"
                        	fi

			else
				echo "$obj_target $resource is Secret managed by Helm. Skipping"
			fi
		done
	else
		echo "$obj_target not found. Skipping"
	fi
}
if [[ $secret_param == "true" ]];then
        if [[ -f $kube_config_source ]];then
                current_ocp=$(oc --kubeconfig $kube_config_source whoami --show-server)
                current_user=$(oc --kubeconfig $kube_config_source whoami 2>/dev/null)
                if [[ ${current_ocp%/} != ${ocp_source%/} || $current_user == "" ]];then
                        oc login -u $ocp_source_user -p $ocp_source_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config_source
                fi
        else
                        oc login -u $ocp_source_user -p $ocp_source_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config_source
        fi

        if [[ -f $kube_config_target ]];then
                current_ocp=$(oc --kubeconfig $kube_config_target whoami --show-server)
                current_user=$(oc --kubeconfig $kube_config_target whoami 2>/dev/null)
                if [[ ${current_ocp%/} != ${ocp_target%/} || $current_user == "" ]];then
                        oc login -u $ocp_target_user -p $ocp_target_pass $ocp_target --insecure-skip-tls-verify=true --kubeconfig $kube_config_target
                fi
        else
                        oc login -u $ocp_target_user -p $ocp_target_pass $ocp_target --insecure-skip-tls-verify=true --kubeconfig $kube_config_target
        fi

	if [[ ! -z $projects ]];then
                for project_name in "${projects[@]}";do
                        verify $project_name
                done
        else
                verify $project_name
        fi
else
	echo "Skipping $obj_target"
fi
