#!/bin/sh
source /root/.bash_profile

# 函数：获取文件列表
# 作用：到指定的目录下，获取该目录下文件列表
function get_file_list {
    local url=$1
    local list=()
    local index=0
	
    cd $url/
    for f in `ls`;
    do
        list[index]=$f
        let index=index+1
    done
	
    echo ${list[*]}
}

# 函数：获取key列表
# 作用：从指定目录的指定配置文件中获取所有key的值
function get_key_from_properties {
    local url=$1
    local properties_file=$2
    local list=()
    local index=0

    cd ${url}/
    dos2unix ${properties_file}
    while read line || [[ -n ${line} ]];
    do
        # 过滤掉配置文件中的注释行（以#开头的行）和空行
        if [[ ${line:0:1} == "#" || ${line} == ""  ]]
        then
            continue
        fi

        # 获取一行最左侧第一个=号左边的字符
        key=${line%%=*}
        list[index]=$key
        let index=index+1
    done<${url}/${properties_file}

    echo ${list[*]}
}

# 函数：是否是key相同的配置文件
# 作用：对比指定的两个配置文件，判断是否是key值相同的配置文件
function is_same_properties {
    local reference_list=($1)
    local target_list=($2)
    local is_same=0

    # 判断两个key数组的长度
    if [[ ${#reference_list[*]} == ${#target_list[*]} ]]
    then
        # 判断长度相等的key数组中的元素是否相同
        for i in `seq 0 ${#reference_list[*]}`
        do
            if [[ "${reference_list[*]}" =~ ${target_list[$i]} ]]
            then
                continue
            else
                is_same=1
            fi
        done
    else
        is_same=1
    fi

    echo ${is_same}
}

#构建平台补丁的codedeploy补丁包
#运行脚本的前提：
#	1、提供平台补丁的下载url；
#	2、补丁包md5验证文件；
#SVN_IP=54.223.31.144
SVN_URL=http://awsidc.waiqin365.com:33690/repos/waiqin365config
SVN_USERNAME_PASSWORD=' --username admin --password admin'

#平台补丁包的组成：
#例如：patch9.1.4-iMobii-Appsvr-2.0.0-build137461-20170605.tar.gz
#
#研发打包路径，通常是一个svn的路径，可通过http方式访问到该资源，例如：
#http://172.31.3.252:8082/release/WaiQin365/Server/Patch9.1.4/patch9.1.4-iMobii-Appsvr-2.0.0-build137461-20170605.tar.gz
#
#通过该url，能解析出压缩包的文件名
patch_package_url=$patch_url
patch_package_url_md5=$patch_package_url.md5
patch_package_tar_file=${patch_package_url##*/}

echo -e  "\npatch_package_url is : ${patch_package_url}"
echo "patch_package_url_md5 is : ${patch_package_url_md5}"
echo -e "patch_package_tar_file is : ${patch_package_tar_file}\n"

#由压缩包的文件名，解析出解压后的文件夹名称
patch_package_file_name=iMobii-Master-2.0.0
echo ${patch_package_file_name}

#下载研发补丁包,并解压
cd /tmp
mkdir ${patch_package_file_name}
cd ${patch_package_file_name}
wget ${patch_package_url}
wget ${patch_package_url_md5}
if [[ -f ${patch_package_tar_file} ]];
then
    local_md5=`md5sum ${patch_package_tar_file}`
    download_md5=`cat ${patch_package_tar_file}.md5`
    if [[ ${local_md5} != ${download_md5} ]];
    then
	echo "download file failed"
	exit 1
    fi
else
    echo "download file is not file"
    exit 1
fi

tar -zxf ${patch_package_tar_file}

# 参数对比
# 1、从svn上随机挑选一个master，获取配置文件列表
# 2、依次读取配置文件中的key值
# 3、将配置文件中key值和patch包中对应配置文件的key值进行比对，判断key值是否都相同
# 4、判断逻辑
#    1)如果所有配置文件的key值都相同，则无需维护配置文件，继续打包
#    2)如果有一个配置文件的一个key值不同，则需要先维护配置文件到svn，停止本地打包
svn co ${SVN_URL}/aws/master/ ${SVN_USERNAME_PASSWORD} --no-auth-cache

cd master/
# 获取所有master列表
master_list=(`get_file_list \`pwd\``)

# 获取properties文件数量
list_total=${#master_list[@]}

# 生成随机数
random_num=$(($RANDOM%${list_total}))

# 从随机数确定参考master
svn_master=${master_list[${random_num}]}

# 从参考master中获取properties文件列表
cd ${svn_master}/
properties_list=(`get_file_list \`pwd\``)

# svn配置文件的本地路径和patch配置文件的本地路劲
svn_propertis_url=/tmp/${patch_package_file_name}/master/${svn_master}
patch_properties_url=/tmp/${patch_package_file_name}/${patch_package_file_name}/patch/Master/web/WEB-INF/classes

# 遍历所有配置文件，并比对每个配置文件中的key值是否相同
cd /tmp/${patch_package_file_name}
for (( i=0; i<${#properties_list[*]}; i++  ))
do
    properties_file=${properties_list[$i]}
    echo -e  "===========================\n准备对比 ${properties_file}\n"
    svn_properties_key=(`get_key_from_properties ${svn_propertis_url}  ${properties_file}`)
    echo -e "svn_properties_key is \n ${svn_properties_key[*]}"
    
	if [[ -f ${patch_properties_url}/${properties_file} ]]
	then
	    patch_properties_key=(`get_key_from_properties ${patch_properties_url} ${properties_file}`)
        echo -e "patch_properties_key is \n ${patch_properties_key[*]}"
	else
        continue
	fi
	
    compare_result=`is_same_properties "${svn_properties_key[*]}" "${patch_properties_key[*]}"`
    if [[ ${compare_result} == "1" ]]
    then
        echo -e "${properties_file} 存在差异,请维护SVN先!\n"
	exit 1
    fi
done

#配置打包目录
cd /tmp
mkdir ${patch_package_file_name}-master



cp -Rf /tmp/${patch_package_file_name}/${patch_package_file_name}/patch/Master/web/ ${patch_package_file_name}-master/
cp -Rf /tmp/${patch_package_file_name}/${patch_package_file_name}/patch/delete.list ${patch_package_file_name}-master/



#下载部署脚本

cd /tmp/${patch_package_file_name}/
svn co ${SVN_URL}/scripts/Master ${SVN_USERNAME_PASSWORD} --no-auth-cache
#拷贝脚本至打包目录
cp -Rf /tmp/${patch_package_file_name}/Master/common/* /tmp/${patch_package_file_name}-master
cp -Rf /tmp/${patch_package_file_name}/Master/master/* /tmp/${patch_package_file_name}-master


#拷贝delete.list至打包目录
cp -Rf /tmp/${patch_package_file_name}/${patch_package_file_name}/patch/delete.list /tmp/${patch_package_file_name}-master/scripts/

#部署文件打包
patch_tar_file=${patch_package_tar_file%.*}
patch_tar_file1=${patch_tar_file%.*}
cd /tmp/${patch_package_file_name}-master
tar -czf ${patch_tar_file1}-master.tar.gz web/ scripts/ appspec.yml
aws s3 cp /tmp/${patch_package_file_name}-master/${patch_tar_file1}-master.tar.gz s3://waiqin365codedeploy/Master/  --storage-class STANDARD_IA




#删除本地目录
cd /tmp
rm -rf ${patch_package_file_name}*




#创建应用程序
aws deploy create-application --application-name $patch_tar_file1

#创建部署组
#创建master部署组
aws deploy create-deployment-group --application-name $patch_tar_file1  --deployment-config-name CodeDeployDefault.OneAtATime --deployment-group-name master --ec2-tag-filters Key=Name,Value=A_WEB_master_50_10_puduction,Type=KEY_AND_VALUE Key=Name,Value=A_WEB_master_50_11_operating,Type=KEY_AND_VALUE --service-role-arn arn:aws-cn:iam::316125133389:role/waiqin365codedeploy


#创建部署
#创建master部署组的部署
aws deploy create-deployment --application-name $patch_tar_file1 --deployment-config-name CodeDeployDefault.OneAtATime --deployment-group-name master --description "master deployment" --file-exists-behavior OVERWRITE --s3-location bucket=waiqin365codedeploy,bundleType=tar,key=Master/${patch_tar_file1}-master.tar.gz







