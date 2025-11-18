#!/bin/bash
#
#
config_file="/home/thinkbook/ocp-bart/ocp-bart/migrate.conf"

if [[ "$#" -eq 7 ]];then
	project_name=$1
	ocp_registry_source=$2
	ocp_registry_source_token=$3
	ocp_registry_target=$4
	ocp_registry_target_token=$5
	image_param=$6
	base_dir=$7
elif [[ $BUILDING_ARGS ]];then
        echo "$0 projectName ocpRegistrySource ocpTokenSource ocpRegistryTarget ocpTokenTarget imageMigrate baseDir"
        exit 0
elif [[ ! -z "$config_file" && -f "$config_file" ]];then
        source "$config_file"
else
        echo "Define \$config_file or"
        echo "Usage: $0 projectName ocpRegistrySource ocpTokenSource ocpRegistryTarget ocpTokenTarget imageMigrate baseDir"
        exit 1
fi

kube_config="${base_dir}/.restore-kubeconfig"

function restore() {
	project_name=$1
	work_dir=$(echo $base_dir/backup/$project_name/image)
	echo "Restoring Image on project $project_name"
	if [[ -d $work_dir ]];then
		read -p "Proceed? (Y/n)" confirm
		
		if [[ $confirm != "Y" ]];then
			echo "Aborted."
			exit 1
		fi
		for img_dir in $(ls $work_dir/);do
			if [[ -f $work_dir/$img_dir/images.txt ]];then
				cat $work_dir/$img_dir/images.txt | while read image;do
					echo "Migrate Image Tag: $image"; \
				        skopeo copy -q --src-creds admin:$ocp_registry_source_token --src-tls-verify=false \
				        --dest-creds admin:$ocp_registry_target_token --dest-tls-verify=false \
				       	docker://${ocp_registry_source}/${project_name}/$image \
				        docker://${ocp_registry_target}/${project_name}/$image
				done
			else
				echo "Skipping. No Image."
			fi
		done
	else
		echo "Skipping. No Image."
	fi
}

if [[ $image_param == "true" ]];then
	if [[ ! -z $projects && -z $project_name ]];then
                for project_name in "${projects[@]}";do
                        restore $project_name
                done
        else
                restore $project_name
        fi
else
        echo "Aborted due to migrate_param $migrate_param"
fi
