#!/bin/bash
#
#

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
elif [[ -z "$config_file" ]];then
        echo "Finding migrate.conf"
        temp_work_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        temp_config_file="$temp_work_dir/../migrate.conf"
        if [[ -f $temp_config_file ]];then
                echo "migrate.conf found. Using configuration files as reference"
                config_file=$temp_config_file
        else
                unset $temp_config_file
                echo "No migrate.conf found"
        fi
fi
if [[ "$#" -ne 7 && -z "$config_file" ]];then
        echo "Define \$config_file or"
        echo "Usage: $0 projectName ocpRegistrySource ocpTokenSource ocpRegistryTarget ocpTokenTarget imageMigrate baseDir"
        exit 1
fi

if [[ ! "$RUN_FROM_MAIN" ]];then
        echo "Finding pre-flight.sh"
        temp_pre_flight="$temp_work_dir/../pre-flight.sh"
        if [[ -f $temp_pre_flight ]];then
                pre_flight=$temp_pre_flight
                script_name=$(basename "${BASH_SOURCE[0]}")
                echo "pre-flight.sh found. Running pre-flight.sh script"
                bash $pre_flight $script_name $config_file
                if [[ $? -eq 0 ]];then
                        echo "All is well"
                        echo "Loading migrate.conf"
                        source $config_file
                else
                        echo "Pre-flight failed. Aborting."
                        exit 1
                fi
        else
                unset $temp_pre_flight
                echo "No pre-flight.sh found"
                exit 1
        fi
fi

kube_config="${base_dir}/.restore-kubeconfig"

function restore() {
	project_name=$1
	work_dir=$(echo $base_dir/backup/$project_name/image)
	echo "Restoring Image on project $project_name"
	if [[ -d $work_dir ]];then
		for img_dir in $(ls $work_dir/);do
			if [[ -f $work_dir/$img_dir/images.txt ]];then
				read -p "Proceed? (Y/n)" confirm
				
				if [[ $confirm != "Y" ]];then
					echo "Aborted."
					exit 1
				fi
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
