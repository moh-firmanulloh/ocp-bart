### Special Variable

Special Variable perlu didefinisikan pada _migrate.conf_, atau inline bash.

|Variable|Expected Value|Remarks|
|--------|--------------|-------|
|exclude_pattern=""|Pattern grep untuk exclude beberapa Secret yg secara default tergenerate saat Project dibuat|Perlu disesuaikan pada script ini. Tidak di-design untuk menjadi script argument untuk menghindari kesalahan dalam penggunaan|

### Script Breakdown

```
			helm_label=$(oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r '.metadata.labels.owner')
			secret_type=$(oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r '.type')
			if [[ $helm_label != "Helm" || $helm_label != "helm" || $secret_type != "helm.sh/release.v1" && $export_helm == "false" ]];then
				echo "Backing up $obj_target: $resource JSON"
				resource_file_name=$(echo $resource | tr ":" "_")
	       			oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .status)' > $work_dir/$obj_target-$resource_file_name.json
				echo "Result path: $work_dir/$obj_target-$resource_file_name.json"
			elif [[ $export_helm == "true" ]];then
				echo "Backing up $obj_target: $resource JSON"
				resource_file_name=$(echo $resource | tr "." "_")
				oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .status)' > $work_dir/$obj_target-$resource_file_name.json
                                echo "Result path: $work_dir/$obj_target-$resource_file_name.json"
			else
				echo "$obj_target $resource is Secret managed by Helm. Skipping"
			fi
```

Pada bagian ini, _helm_label_ akan mengambil value dari _.metadata.labels.owner_, dan _secret_type_ akan mengambil value dari _.type_.

Jika value dari _helm_label_ bukanlah "Helm" ataupun "helm", atau value dari _secret_type_ bukanlah "helm.sh/release.v1", dan value dari _export_helm_ adalah "false", maka Secret yang di backup hanyalah Secret yang match dengan kondisi ini.

Jika value dari _export_helm_ "true", maka seluruh Secret termasuk yang di manage oleh Helm dan Secret yang dengan type "helm.sh/release.v1" juga akan dibackup/export.

Selain dua kondisi diatas, berarti kondisi yang memungkinkan adalah ketika value dari _export_helm_ adalah "false", akan tetapi value dari _helm_label_ adalah "Helm" atau "helm", atau value dari _secret_type_ adalah "helm.sh/release.v1". Hingga, pada kondisi ini akan men-skip Secret tersebut.
