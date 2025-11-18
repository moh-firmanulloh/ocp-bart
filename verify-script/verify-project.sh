#!/bin/bash
#
#
obj_target="project"
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
	project_param=$8
	base_dir=${9%/}
elif [[ $BUILDING_ARGS ]];then
	echo "$0 projectName ocpSourceApiURL ocpSourceUser ocpSourcePass ocpTargetApiURL ocpTargetUser ocpTargetPass projectMigrate baseDir"
	exit 0
elif [[ ! -z "$config_file" && -f "$config_file" ]];then
	source "$config_file"
else
	echo "Define \$config_file or"
	echo "Usage: $0 projectName ocpSourceApiURL ocpSourceUser ocpSourcePass ocpTargetApiURL ocpTargetUser ocpTargetPass projectMigrate baseDir"
	exit 1
fi

work_dir=$(echo $base_dir/backup/$project_name)
kube_config_source="${base_dir}/.backup-kubeconfig"
kube_config_target="${base_dir}/.restore-kubeconfig"

echo "Source: $ocp_source"
echo "Target: $ocp_target"

function verify() {
	project_name=$1
	obj_res=$(oc --kubeconfig $kube_config_source get $obj_target $project_name)
	if [[ $? == 0 ]];then
		echo "Checking $obj_target $project_name"
		source_hash=$(oc --kubeconfig $kube_config_source get $obj_target $project_name -ojson | jq -r 'del(.metadata.annotations."openshift.io/sa.scc.mcs",.metadata.annotations."openshift.io/sa.scc.supplemental-groups",.metadata.annotations."openshift.io/sa.scc.uid-range",.metadata.creationTimestamp,.metadata.labels."pod-security.kubernetes.io/audit",.metadata.labels."pod-security.kubernetes.io/audit-version",.metadata.labels."pod-security.kubernetes.io/warn",.metadata.labels."pod-security.kubernetes.io/warn-version",.metadata.resourceVersion, .metadata.uid, .spec, .status)' | sha256sum)
		target_hash=$(oc --kubeconfig $kube_config_target get $obj_target $project_name -ojson | jq -r 'del(.metadata.annotations."openshift.io/sa.scc.mcs",.metadata.annotations."openshift.io/sa.scc.supplemental-groups",.metadata.annotations."openshift.io/sa.scc.uid-range",.metadata.creationTimestamp,.metadata.labels."pod-security.kubernetes.io/audit",.metadata.labels."pod-security.kubernetes.io/audit-version",.metadata.labels."pod-security.kubernetes.io/warn",.metadata.labels."pod-security.kubernetes.io/warn-version",.metadata.resourceVersion, .metadata.uid, .spec, .status)' | sha256sum)
		if [[ $target_hash != $source_hash ]];then
			echo -e "$obj_target: $project_name ${RED}does not match${NC}"
		else
			echo -e "$obj_target: $project_name ${GREEN}match${NC}"
		fi
	else
		echo "$obj_target not found. Aborting.."
		exit 1
	fi
}

if [[ $project_param == "true" ]];then
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
	
	if [[ ! -z $projects && -z $project_name ]];then
                for project_name in "${projects[@]}";do
                        verify $project_name
                done
        else
                verify $project_name
        fi
else
	echo "Aborting.."
	exit 1
fi
