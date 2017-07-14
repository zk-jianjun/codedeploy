#!/bin/sh
# --------------------------------------------------------------------------------
# 本脚本用于构建CodeDeploy部署补丁包
#
# 运行脚本的前提：
#	1、提供应用补丁的下载url；
#	2、补丁包md5验证文件；
#
# 运行方式：
# sh build_codedeploy_patch_application.sh http://zk.waiqin365.com:10010/zhuyin/appmodule-dms-1.0.7-build137420-20170605.tar.gz 
# 
# 应用补丁包名称的组成：
# 1、appmodule开头
# 2、应用简称
# 3、版本号
# 4、build号
# 5、打包日期
# 6、.tar.gz后缀
# 7、其中1、2、3、4、5之前用-连接
# 例如：appmodule-dms-1.0.7-build137420-20170605.tar.gz
# --------------------------------------------------------------------------------
#对补丁包文件名进行解析，去掉4、5、6部分，得到应用包解压缩之后的文件夹名称
#通过函数调用，去掉最右边一个-符号右边的字符串

source /root/.bash_profile
#SVN_IP=54.223.31.144
SVN_URL=http://awsidc.waiqin365.com:33690/repos/waiqin365config
SVN_USERNAME_PASSWORD=' --username admin --password admin'

# 函数：去掉右侧连字符
# 作用：从右边开始，删除第一个-号及右边的字符
# 例如：
#   输入 appmodule-dms-1.0.7-build137420-20170605.tar.gz
#   输出 appmodule-dms-1.0.7-build137420
function remove_right_hyphen {
    file_name=$1
    echo ${file_name%-*}
}

# 函数：去掉左侧连字符
# 作用：从左边开始，删除第一个-号及左边的字符
# 例如：
#   输入 appmodule-dms-1.0.7-build137420-20170605.tar.gz
#   输出 dms-1.0.7-build137420-20170605.tar.gz
function remove_left_hyphen {
    file_name=$1
    echo ${file_name#*-}
}

# 函数：去掉右侧点号
# 作用：从右边开始，删除第一个.号及右边的字符
# 例如：
#   输入 appmodule-dms-1.0.7-build137420-20170605.tar.gz
#   输出 appmodule-dms-1.0.7-build137420-20170605.tar
function remove_right_dot {
    file_name=$1
    echo ${file_name%.*}
}

# 函数：获取补丁包文件名
# 作用：去除.tar.gz后缀，获取补丁包文件名
# 例如：
#   输入 appmodule-dms-1.0.7-build137420-20170605.tar.gz
#   输出 appmodule-dms-1.0.7-build137420-20170605
function get_patch_package_mark {
    mark=$1
    for (( j=1; j<=2; j++  ))
    do
	mark=`remove_right_dot ${mark}`
    done
    echo ${mark}
}

# 函数：获取补丁包文件夹名
# 作用：去除.tar.gz后缀，去除build号和日期，获取补丁包文件夹名
# 例如：
#   输入 appmodule-dms-1.0.7-build137420-20170605.tar.gz
#   输出 appmodule-dms-1.0.7
function get_patch_package_file_name {
    patch_package_file_name=$1
    for (( i=1; i<=2; i++  ))
    do
	patch_package_file_name=`remove_right_hyphen ${patch_package_file_name}`
    done
    echo ${patch_package_file_name}
}

# 研发打包路径，通常是一个svn的路径，可通过http方式访问到该资源，例如：
# http://172.31.3.252:8082/release/WaiQin365/Application/dms/dms-1.0.8/appmodule-dms-1.0.7-build137420-20170605.tar.gz
#
# 通过该url，能解析出一下变量
#   patch_package_tar_file：tar包文件名，例如：appmodule-dms-1.0.7-build137420-20170605.tar.gz
#   patch_package_mark：补丁包文件名，例如：appmodule-dms-1.0.7-build137420-20170605
#   patch_package_file_name：补丁包文件夹名，例如：appmodule-dms-1.0.7
patch_package_url=$patch_url
patch_package_url_md5=$patch_package_url.md5
patch_package_tar_file=${patch_package_url##*/}
patch_package_mark=`get_patch_package_mark ${patch_package_tar_file}`
patch_package_file_name=`get_patch_package_file_name ${patch_package_tar_file}`

echo -e "\npatch_package_url is : ${patch_package_url}"
echo "patch_package_url_md5 is : ${patch_package_url_md5}"
echo "patch_package_tar_file is : ${patch_package_tar_file}"
echo "patch_package_mark is : ${patch_package_mark}"
echo -e "patch_package_file_name is : ${patch_package_file_name}\n"

# 下载补丁包,并解压,并通过md5文件验证下载是否有效
# 在/tmp目录下，通过补丁包文件夹名新建目录，来存在打包过程中的零时文件
# 例如：
#   在/tmp/appmodule-dms-1.0.7下，通过appmodule-dms-1.0.7-build137420-20170605.tar.gz补丁包构建CodeDeploy部署补丁包
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

# 配置打包目录
mkdir ${patch_package_file_name}-appsvr
mkdir ${patch_package_file_name}-upload
#mkdir ${patch_package_file_name}-track
mkdir ${patch_package_file_name}-si
sleep 2

# 拷贝web目录到打包目录
cp -Rf ${patch_package_file_name}/web/ ${patch_package_file_name}-appsvr/
cp -Rf ${patch_package_file_name}/web/ ${patch_package_file_name}-upload/
#cp -Rf ${patch_package_file_name}/web/ ${patch_package_file_name}-track/
cp -Rf ${patch_package_file_name}/web/ ${patch_package_file_name}-si/

# 从svn下载部署脚本
/usr/bin/svn checkout ${SVN_URL}/scripts/Application/ ${SVN_USERNAME_PASSWORD} --no-auth-cache
sleep 2

# 拷贝公共脚本到打包目录
cp -Rf Application/common/* ${patch_package_file_name}-appsvr/
cp -Rf Application/common/* ${patch_package_file_name}-upload/
#cp -Rf Application/common/* ${patch_package_file_name}-track/
cp -Rf Application/common/* ${patch_package_file_name}-si/

# 拷贝个性化脚本到打包目录
cp -Rf Application/appsvr/* ${patch_package_file_name}-appsvr/
cp -Rf Application/upload/* ${patch_package_file_name}-upload/
#cp -Rf Application/track/* ${patch_package_file_name}-track/
cp -Rf Application/si/* ${patch_package_file_name}-si/

# 修改补丁包中的delete_old_app.sh脚本，方便CodeDeploy部署脚本调用
#   1、将. scripts/shell/CONFIG替换成. scripts/CONFIG
#   2、将delete_old_app.sh脚本组装到运维补丁包中
sed -i 's/scripts\/shell\/CONFIG/$(dirname $0)\/CONFIG/g' ${patch_package_file_name}/delete_old_app.sh
cp ${patch_package_file_name}/delete_old_app.sh ${patch_package_file_name}-appsvr/scripts/
cp ${patch_package_file_name}/delete_old_app.sh ${patch_package_file_name}-upload/scripts/
#cp ${patch_package_file_name}/delete_old_app.sh ${patch_package_file_name}-track/scripts/
cp ${patch_package_file_name}/delete_old_app.sh ${patch_package_file_name}-si/scripts/


# 打包
cd ${patch_package_file_name}-appsvr/
tar -zcf ../${patch_package_mark}-appsvr.tar.gz *
cd ../${patch_package_file_name}-upload/
tar -zcf ../${patch_package_mark}-upload.tar.gz *
#cd ../${patch_package_file_name}-track/
#tar -zcf ../${patch_package_mark}-track.tar.gz *
cd ../${patch_package_file_name}-si/
tar -zcf ../${patch_package_mark}-si.tar.gz *
cd ../

# 上传CodeDeploy部署补丁包到S3，S3中bucket名称：waiqin365codedeploy
/usr/bin/aws s3 cp ${patch_package_mark}-appsvr.tar.gz s3://waiqin365codedeploy/Application/ --storage-class STANDARD_IA
/usr/bin/aws s3 cp ${patch_package_mark}-upload.tar.gz s3://waiqin365codedeploy/Application/ --storage-class STANDARD_IA
#/usr/bin/aws s3 cp ${patch_package_mark}-track.tar.gz s3://waiqin365codedeploy/Application/ --storage-class STANDARD_IA
/usr/bin/aws s3 cp ${patch_package_mark}-si.tar.gz s3://waiqin365codedeploy/Application/ --storage-class STANDARD_IA
sleep 2

# 删除本地打包零时目录
cd /tmp
rm -rf ${patch_package_file_name}


#创建应用程序
aws deploy create-application --application-name $patch_package_mark


#创建部署组
#创建appsvr部署组
aws deploy create-deployment-group --application-name $patch_package_mark  --deployment-config-name CodeDeployDefault.HalfAtATime --deployment-group-name appsvr --ec2-tag-filters Key=Name,Value=A_WEB_appsvr_30_10,Type=KEY_AND_VALUE Key=Name,Value=A_WEB_appsvr_30_11,Type=KEY_AND_VALUE Key=Name,Value=A_WEB_appsvr_30_12,Type=KEY_AND_VALUE Key=Name,Value=A_WEB_appsvr_30_13,Type=KEY_AND_VALUE  --service-role-arn arn:aws-cn:iam::316125133389:role/waiqin365codedeploy
#创建upload部署组
aws deploy create-deployment-group --application-name $patch_package_mark  --deployment-config-name CodeDeployDefault.OneAtATime --deployment-group-name upload --ec2-tag-filters Key=Name,Value=A_WEB_upload_30_20,Type=KEY_AND_VALUE Key=Name,Value=A_WEB_upload_30_21,Type=KEY_AND_VALUE --service-role-arn arn:aws-cn:iam::316125133389:role/waiqin365codedeploy
#创建track部署组
#aws deploy create-deployment-group --application-name $patch_package_mark  --deployment-config-name CodeDeployDefault.OneAtATime --deployment-group-name #track --ec2-tag-filters Key=Name,Value=A_WEB_track_30_14,Type=KEY_AND_VALUE  --service-role-arn arn:aws-cn:iam::316125133389:role/waiqin365codedeploy
#创建本地实例部署组
aws deploy create-deployment-group --application-name $patch_package_mark  --deployment-config-name CodeDeployDefault.AllAtOnce --deployment-group-name si --on-premises-instance-tag-filters Key=Name,Value=gzxijiu,Type=KEY_AND_VALUE  Key=Name,Value=wissun,Type=KEY_AND_VALUE  Key=Name,Value=xianchida,Type=KEY_AND_VALUE  Key=Name,Value=xianju,Type=KEY_AND_VALUE --service-role-arn arn:aws-cn:iam::316125133389:role/waiqin365codedeploy


#创建部署
#创建appsvr部署组的部署
aws deploy create-deployment --application-name $patch_package_mark --deployment-config-name CodeDeployDefault.HalfAtATime --deployment-group-name appsvr --description "appsvr deployment" --file-exists-behavior OVERWRITE --s3-location bucket=waiqin365codedeploy,bundleType=tar,key=Application/${patch_package_mark}-appsvr.tar.gz

#创建upload部署组的部署
aws deploy create-deployment --application-name $patch_package_mark --deployment-config-name CodeDeployDefault.OneAtATime --deployment-group-name upload --description "upload deployment" --file-exists-behavior OVERWRITE --s3-location bucket=waiqin365codedeploy,bundleType=tar,key=Application/${patch_package_mark}-upload.tar.gz

#创建本地实例部署组的部署
aws deploy create-deployment --application-name $patch_package_mark --deployment-config-name CodeDeployDefault.AllAtOnce --deployment-group-name si --description "si deployment" --file-exists-behavior OVERWRITE --s3-location bucket=waiqin365codedeploy,bundleType=tar,key=Application/${patch_package_mark}-si.tar.gz