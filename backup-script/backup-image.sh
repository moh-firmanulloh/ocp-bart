#!/bin/bash
#
#
obj_list="deployment deploymentconfig daemonset statefulset cronjob"
config_file="/home/thinkbook/ocp-bart/ocp-bart/migrate.conf"

if [[ "$#" -eq 6 ]];then
	project_name=$1
	ocp_source="${2%/}"
	ocp_user=$3
	ocp_pass=$4
	migrate_param=$5
	base_dir=$6
elif [[ $BUILDING_ARGS ]];then
        echo "$0 projectName ocpApiURL ocpUser ocpPass imageMigrate baseDir"
        exit 0
elif [[ ! -z "$config_file" && -f "$config_file" ]];then
        source "$config_file"
else
        echo "Define \$config_file or"
        echo "Usage: $0 projectName ocpApiURL ocpUser ocpPass imageMigrate baseDir"
        exit 1
fi

kube_config="${base_dir}/.backup-kubeconfig"

echo "Source: $ocp_source"

function img_pattern_non_cj {
        container_num=$1
        oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r --arg n "$container_num" '.spec.template.spec.containers[$n|tonumber].image'
}

function img_pattern_cj {
        container_num=$1
        oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r --arg n "$container_num" '.spec.jobTemplate.spec.template.spec.containers[$n|tonumber].image'
}

function img_result {
	img_pattern=$1
        full_pattern=$(echo $img_pattern | tr -dc '/' | wc -c)
        repo_name=$(echo $img_pattern | cut -d"/" -f1)
	img_project=$(echo $img_pattern | cut -d"/" -f2)
	digest=$(echo $img_pattern | grep -o '@sha256:[a-f0-9]\+')
        if [ "$full_pattern" -eq 2 ];then
                if [[ $repo_name == "image-registry.openshift-image-registry.svc:5000" && $img_project != "openshift" ]];then
			if [[ "$digest" == *@sha256:* ]];then
				tag=$(oc --kubeconfig $kube_config get imagestream -n $project_name -ojson | jq -r --arg d "$digest" '.items[] | {name: .metadata.name, tag: (.status.tags[]? | select(.items[].dockerImageReference | endswith($d)) | .tag)} | select(.tag != null) | .tag')
				imagestream=$(echo $img_pattern | cut -d"/" -f3 | cut -d"@" -f1)
				img_name=$(echo "$imagestream:$tag")
        	                echo $img_name >> $work_dir/$obj_target/images.txt
			else
	                        img_name=$(echo $img_pattern | cut -d"/" -f3)
        	                echo $img_name >> $work_dir/$obj_target/images.txt
			fi
		elif [[ $img_project == "openshift" || $repo_name != "image-registry.openshift-image-registry.svc:5000" ]];then
			echo "Putting $obj_target: $resource image as non migrated"
			echo "$project_name,$resource,$img_pattern" >> $work_dir/$obj_target/non-migrated.txt
                fi
        else
                echo "Putting $obj_target: $resource image as non migrated"
                echo "$project_name,$resource,$img_pattern" >> $work_dir/$obj_target/non-migrated.txt
        fi
}

function backup() {
	project_name=$1
	work_dir=$(echo $base_dir/backup/$project_name/image)
	echo "Backing up Image on project $project_name"
        for obj_target in $(echo $obj_list);do
                readarray -t obj_res < <(oc --kubeconfig $kube_config get $obj_target -n $project_name --no-headers -o custom-columns=NAME:.metadata.name)
                if [[ "${#obj_res[@]}" -ne 0 ]];then
                        mkdir -p $(echo $work_dir/$obj_target)
                        for resource in "${obj_res[@]}";do
                                counter=0
                                echo "Checking $obj_target: $resource image pattern"
                                if [[ $obj_target == "cronjob" ]];then
                                        container_length=$(oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r '.spec.jobTemplate.spec.template.spec.containers | length')
                                        for ((counter=0;counter<container_length;counter++));do
                                                img_pattern=$(img_pattern_cj $counter)
						img_result $img_pattern
                                        done
                                else
                                        container_length=$(oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r '.spec.template.spec.containers | length')
                                        for ((counter=0;counter<container_length;counter++));do
                                        	img_pattern=$(img_pattern_non_cj $counter)
						img_result $img_pattern
                                        done
                                fi
                        done
                else
                        echo "$obj_target not found. Skipping"
                fi
        done
}
if [[ $image_param == "true" ]];then
	if [[ -f $kube_config ]];then
	        current_ocp=$(oc --kubeconfig $kube_config whoami --show-server)
	        current_user=$(oc --kubeconfig $kube_config whoami 2>/dev/null)
	        if [[ ${current_ocp%/} != ${ocp_source%/} || $current_user == "" ]];then
	                oc login -u $ocp_user -p $ocp_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config
	        fi
	else
	                oc login -u $ocp_user -p $ocp_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config
	fi

	if [[ ! -z $projects && -z $project_name ]];then
                for project_name in "${projects[@]}";do
                        backup $project_name
                done
        else
                backup $project_name
        fi

else
        echo "Skipping $obj_target"
fi
