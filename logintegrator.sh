#!/bin/bash -evx

########################################
# Logrotate & S3 uploader
#
# 引数
# $1:logファイルのDirPath
# $2:統合する期間
#
# Written by hiramatsu 2018.6.25
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
SYSD=$(pwd)


#########################
#env 読み込み
AWS_ACCESS_KEY_ID=`cat ./env | awk 'BEGIN {FS="="} $1=="AWS_ACCESS_KEY_ID" {print $2}' | sed 's/"//g'`
AWS_SECRET_ACCESS_KEY=`cat ./env | awk 'BEGIN {FS="="} $1=="AWS_SECRET_ACCESS_KEY" {print $2}' | sed 's/"//g'`
S3_BUCKET_NAME=`cat ./env | awk 'BEGIN {FS="="} $1=="S3_BUCKET_NAME" {print $2}' | sed 's/"//g'`
S3_BUCKET_ADDR="s3://${S3_BUCKET_NAME}"

echo ${AWS_ACCESS_KEY_ID}
echo ${AWS_SECRET_ACCESS_KEY}
echo ${S3_BUCKET_NAME}
echo ${S3_BUCKET_ADDR}

exit 0


#取得する日付を指定

#########################
#S3からログをDL

#DLをunzip

#Dir階層を破ってログファイルを検索（日付期間内のファイルのみ)

#検索ファイルから各host ipを取得

#TMP Dirを作成

#TMPの下にhosot ipのDirを作成

#検索ファイルをip host ごとのDirに移動

#ip hostごとに以下の処理を行う

#検索ファイルをaccess, system, errorごとにファイル結合（ソートは日付順）aws



########################
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
