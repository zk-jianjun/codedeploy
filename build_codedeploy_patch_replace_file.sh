#!/bin/sh
# --------------------------------------------------------------------------------
# 本脚本用于构建CodeDeploy部署补丁包
#
# 运行脚本的前提：
#	1、提供替换文件补丁的下载url；
#
# 运行方式：
# sh build_codedeploy_patch_application.sh http://zk.waiqin365.com:10010/zhuyin/appmodule-dms-replacefile-Test-1654-20170615170830.zip
# 
# 应用补丁包名称的组成：
# 1、appmodule开头
# 2、应用简称
# 3、replacefile
# 4、Jira号
# 5、日期时间戳
# 6、.zip后缀
# 7、其中1、2、3、4、5之前用-连接
# 例如：appmodule-dms-replacefile-Test-1654-20170615170830.zip
# --------------------------------------------------------------------------------

source /root/.bash_profile
#SVN_IP=54.223.31.144
SVN_URL=http://awsidc.waiqin365.com:33690/repos/waiqin365config
SVN_USERNAME_PASSWORD=' --username admin --password admin'

# 函数：去掉右侧点号
# 作用：从右边开始，删除第一个.号及右边的字符
# 例如：
#   输入 appmodule-dms-replacefile-Test-1654-20170615170830.zip
#   输出 appmodule-dms-replacefile-Test-1654-20170615170830
function remove_right_dot {
    file_name=$1
    echo ${file_name%.*}
}

# 替换文件补丁包由测试部提供，可通过http方式访问到该资源，例如：
# http://zk.waiqin365.com:10010/20170615/appmodule-dms-replacefile-Test-1654-20170615170830.zip
#
# 通过该url，能解析出一下变量
#   patch_package_tar_file:zip包文件名，例如：appmodule-dms-replacefile-Test-1654-20170615170830.zip
#   patch_package_mark:补丁包文件名，例如：appmodule-dms-replacefile-Test-1654-20170615170830
patch_package_url=$patch_url
patch_package_tar_file=${patch_package_url##*/}
patch_package_mark=`remove_right_dot ${patch_package_tar_file}`

echo -e "\npatch_package_url is : ${patch_package_url}"
echo "patch_package_url_md5 is : ${patch_package_url_md5}"
echo "patch_package_tar_file is : ${patch_package_tar_file}"
echo -e "patch_package_mark is : ${patch_package_mark}\n"
echo -e "customfield_10101 is : ${customfield_10101}\n"  #addby zhouy
echo -e "test发布版本release路径 is : ${test发布版本release路径}\n"  #addby zhouy 
echo -e "jiraReleaseVersion is : ${jiraReleaseVersion}\n"  #addby zhouy


# 下载补丁包,并解压
# 在/tmp目录下，通过补丁包文件夹名新建目录，来存在打包过程中的零时文件
# 例如：
#   在/tmp/appmodule-dms-replacefile-Test-1654-20170615170830下，通过appmodule-dms-replacefile-Test-1654-20170615170830.zip补丁包构建CodeDeploy部署补丁包
cd /tmp
mkdir ${patch_package_mark}
cd ${patch_package_mark}
wget ${patch_package_url}
if [[ -f ${patch_package_tar_file} ]];
then
	echo "download ${patch_package_tar_file} sucess"
else
    echo "download file is not file"
    exit 1
fi

unzip ${patch_package_tar_file}

# 配置打包目录
mkdir ${patch_package_mark}-appsvr
mkdir ${patch_package_mark}-upload
#mkdir ${patch_package_mark}-track
mkdir ${patch_package_mark}-si
sleep 2

# 拷贝web目录到打包目录
cp -Rf web/ ${patch_package_mark}-appsvr/
cp -Rf web/ ${patch_package_mark}-upload/
#cp -Rf web/ ${patch_package_mark}-track/
cp -Rf web/ ${patch_package_mark}-si/

# 从svn下载部署脚本
/usr/bin/svn checkout ${SVN_URL}/scripts/Application_replace_file/ ${SVN_USERNAME_PASSWORD} --no-auth-cache
sleep 2

# 拷贝公共脚本到打包目录
cp -Rf Application_replace_file/common/* ${patch_package_mark}-appsvr/
cp -Rf Application_replace_file/common/* ${patch_package_mark}-upload/
#cp -Rf Application_replace_file/common/* ${patch_package_mark}-track/
cp -Rf Application_replace_file/common/* ${patch_package_mark}-si/

# 拷贝个性化脚本到打包目录
cp -Rf Application_replace_file/appsvr/* ${patch_package_mark}-appsvr/
cp -Rf Application_replace_file/upload/* ${patch_package_mark}-upload/
#cp -Rf Application_replace_file/track/* ${patch_package_mark}-track/
cp -Rf Application_replace_file/si/* ${patch_package_mark}-si/

# 打包
cd ${patch_package_mark}-appsvr/
tar -zcf ../${patch_package_mark}-appsvr.tar.gz *
cd ../${patch_package_mark}-upload/
tar -zcf ../${patch_package_mark}-upload.tar.gz *
#cd ../${patch_package_mark}-track/
#tar -zcf ../${patch_package_mark}-track.tar.gz *
cd ../${patch_package_mark}-si/
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
rm -rf ${patch_package_mark}


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
#aws deploy create-deployment --application-name $patch_package_mark --deployment-config-name CodeDeployDefault.AllAtOnce --deployment-group-name si --description "si deployment"  --file-exists-behavior OVERWRITE --s3-location bucket=waiqin365codedeploy,bundleType=tar,key=Application/${patch_package_mark}-si.tar.gz