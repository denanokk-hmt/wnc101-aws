#!/bin/bash -evx

########################################
# Logrotate & S3 uploader
#
# 引数
# $1:log file Dirpath:省略した場合、本スクリプトと同Dir
# 
# 対象ログファイルのファイル名フォーマット
# yyyymmdd_*.log
#
# Written by hiramatsu 2018.5.17
########################################

#########################
#Error Check
ERR_CHK() {
  STATUS=${PIPESTATUS[@]}
  for s in ${STATUS}; do
    if [ ${s} -eq 0 ]; then
      :
    else
      echo "Error:$1"
      echo "Exec stop."
      exit 0
    fi
  done
  echo "$1:no problem..."
  return
}

#########################
#基本設定
cd `dirname $0`
tmp=/tmp/tmp_$1
LANG=ja_JP.UTF-8
HOSTNAME=$(hostname)
SYSD=$(pwd)
CUST=$(cat ./env)

#########################
#create script log file Dir
if [ -e ${SYSD}/LOG ]; then
  :
else
  mkdir ${SYSD}/LOG
  ERR_CHK "ローテート処理ログディレクトの作成"
fi

#########################
#create script error log file
exec 2> ${SYSD}/LOG/log.$(basename $0).$(date +%Y%m%d).$(date +%H%M%S).$$
#exec 2>> ./LOG/log.$(basename $0).$(date +%Y%m%d)

#########################
#AWS parameter
#export AWS_CONFIG_FILE="/root/.aws/config"
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
#S3_BUCKET_NAME=""
S3_BUCKET_NAME="sss.sss"
S3_BUCKET_ADDR="s3://${S3_BUCKET_NAME}"

#########################
#Rotate destination direcotry($1 argument)
LOGD=${1:-'.'}

#########################
#Rotete date(2Days before)
DAYS=2
UNIX=$(man date | tail -n1 | awk '{print $1}')
if [ ${UNIX} = "BSD" ]; then
  RDATE=$(date -v-2d "+%Y%m%d")
else
  RDATE=$(date -d "2 days ago" "+%Y%m%d")
fi
ERR_CHK "Get 2Days BFR"
echo "ログローテート対象:${RDATE}以前のログファイルを取得"

#########################
#Get rotete logfile name
LOGS=()
LOGS_PATH=()
for filepath in $(ls -a ${LOGD} | awk '/.log/ {print $1}'); do
  if [ "$(echo $filepath | cut -d"_" -f1)" -le "${RDATE}" ]; then
    echo $filepath
    LOGS=(${LOGS[@]} "$filepath")
    LOGS_PATH=(${LOGS_PATH[@]} "${LOGD}/$filepath")
  fi
done
if [ ${#LOGS[@]} -eq 0 ]; then
  false
else
  true
fi
ERR_CHK "ログファイルの取得"
BEGIN=$(echo ${LOGS[0]} | cut -d"_" -f1)
END=$(echo ${LOGS[${#LOGS[@]}-1]} | cut -d"_" -f1)
echo "${#LOGS[@]}ファイルをローテート/期間:${BEGIN}-${END}"

#########################
#Archive
ZIPFILE=${BEGIN}-${END}.${HOSTNAME}.zip
if [ -e ./backup ]; then
  :
else
  mkdir ./backup
  ERR_CHK "backupディレクトリを作成"
fi
rm -f ./backup/${ZIPFILE}
ERR_CHK "同名バックアップファイルの削除"
zip -r ./backup/${ZIPFILE} ${LOGS_PATH[@]}
ERR_CHK "バックアップファイルの作成(圧縮)"

#########################
#S3 Bucket Check
echo "S3バケットの確認中..."
S3_BUCKET_IS=0
for s3b in $(aws s3 ls); do
  if [ "${s3b}" = "${S3_BUCKET_NAME}" ]; then
    S3_BUCKET_IS=1
  fi
done

#########################
#S3 Bucket createion
if [ ${S3_BUCKET_IS} -ne 1 ]; then
  echo "S3バケット作成中..."
  aws s3 mb ${S3_BUCKET_ADDR}
  ERR_CHK "S3 バケットの作成"
fi

#########################
#S3 Upload
echo "S3ファイルアップロード準備中..."
aws s3 sync ./backup ${S3_BUCKET_ADDR}/backup/${CUST}
ERR_CHK "バックアップファイルをS3にアップロード"

#########################
#S3 Uploaded check
UPLOADED=$(aws s3 ls ${S3_BUCKET_ADDR}/backup/ --recursive | grep ${ZIPFILE})
if [ -n "${UPLOADED}" ]; then
  echo "アップロード確認結果:${UPLOADED}"
else
  echo "Upload Error"
fi

#########################
#Log file delete
for filepath in $(ls -a ${LOGD} | awk '/.log/ {print $1}'); do
  if [ "$(echo $filepath | cut -d"_" -f1)" -le "${RDATE}" ]; then
    echo $filepath
    LOGS=(${LOGS[@]} "$filepath")
    LOGS_PATH=(${LOGS_PATH[@]} "${LOGD}/$filepath")
  fi
done


rm -f ${LOGS_PATH[@]}
rm -rf ./backup
ERR_CHK "ローテート済のログファイルを削除"

echo "Exec fin."

exit 0
