#!/bin/bash -evx

########################################
# Logrotate & S3 uploader
#
# 引数
# $1:logファイルのDirPath
# $2:統合する期間 YYYYMMDD-YYYYMMDD 
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

################################
#基本設定
################################
cd `dirname $0`
tmp=/tmp/tmp_$1
LANG=ja_JP.UTF-8
SYSD=$(pwd)
ENV=${SYSD}/ENV/env
S3_DL=${SYSD}/S3_DL


################################
#VALIDATION1
################################
if [ -z "$1" ]; then
  echo "[VAILD ERR] You do not set 1st option dir path."
  exit 0
fi
if [ -z "$2" ]; then
  echo "[VALID ERR] You do not set 2nd option FROM-TO."
  exit 0
fi


################################
#引数
################################
LOGD=$1
FROM_TO=$2
FROM=${FROM_TO:0:8}
TO=${FROM_TO:9:8}

################################
#VALIDATION2
################################
if [ -e "$1" ]; then
  :
else
  echo "[VAILD ERR] Your set dir dose not exits."
  exit 0
fi

echo $FROM
echo $TO
if [ ${FROM} -gt ${TO} ]; then
  echo "[VALID ERR] You set FROM-TO is not right."
  exit 0
fi


################################
#env 読み込み
################################
AWS_ACCESS_KEY_ID=`cat $ENV | awk 'BEGIN {FS="="} $1=="AWS_ACCESS_KEY_ID" {print $2}' | sed 's/"//g'`
AWS_SECRET_ACCESS_KEY=`cat $ENV | awk 'BEGIN {FS="="} $1=="AWS_SECRET_ACCESS_KEY" {print $2}' | sed 's/"//g'`
S3_BUCKET_NAME=`cat $ENV | awk 'BEGIN {FS="="} $1=="S3_BUCKET_NAME" {print $2}' | sed 's/"//g'`
S3_BUCKET_ADDR="s3://${S3_BUCKET_NAME}"


################################
#S3 Bucket Check
################################
echo "S3バケットの確認中..."
S3_IS=0
for s3b in $(aws s3 ls); do
  if [ "${s3b}" = "${S3_BUCKET_NAME}" ]; then
    S3_IS=1
  fi
done
if [ "${S3_IS}" = 0 ]; then
  echo "could not find your S3 Bucket [${S3_BUCKET_NAME}]. Please check AWS S3 settings."
  exit 0
else
  echo "Got it your S3 Bucket [${S3_BUCKET_NAME}]."  
fi


################################
#S3 ls
################################
aws s3 ls ${S3_BUCKET_ADDR}/backup/ur --recursive | cut -d"/" -f3 > ${S3_DL}/tmp-s3-ls
cat ${S3_DL}/tmp-s3-ls | awk 'BEGIN {FS="."} {print $1,$2,sprintf("%s.%s.%s",$1,$2,$3)}' | sort > ${S3_DL}/tmp-s3-ls-from-to      


################################
#S3からホスト名を取得(uniq)
################################
#HOST_NAMES=`aws s3 ls ${S3_BUCKET_ADDR}/backup/ur --recursive | cut -d"/" -f3 | cut -d"." -f2`
HOST_NAMES=`cat ${S3_DL}/tmp-s3-ls | cut -d"/" -f3 | cut -d"." -f2`
rm -f ${S3_DL}/tmp-s3-hosts*
for host in $(echo ${HOST_NAMES}); do
  echo $host >> ${S3_DL}/tmp-s3-hosts
done
cat ${S3_DL}/tmp-s3-hosts | awk '!colname[$1]++{print $1}' | sort > ${S3_DL}/tmp-s3-hosts-uniq


################################
#ホスト名Dirを作成
################################
#cat ${S3_DL}/tmp-s3-hosts-uniq
for host in $(cat ${S3_DL}/tmp-s3-hosts-uniq); do
  echo $host
  if [ -d "${S3_DL}/$host" ]; then
    :
  else
    mkdir ${S3_DL}/$host
  fi
done


#########################
#S3からログをDL
cat ${S3_DL}/tmp-s3-ls | 
cut -d "." -f1 | 
awk -v from=${FROM} -v to=${TO} 'BEGIN {FS="-"} $2>=from&&$1<from || $1>=from&&$2<=to || $1<=to&&$2>=from {print $1,$2}' | awk '!colname[$1$2]++{print $1,$2}' | sort | awk '{print(sprintf("%s-%s",$1,$2))}' > ${S3_DL}/tmp-s3-from-to


#cat ${S3_DL}/tmp-s3-ls-from-to 
#cat ${S3_DL}/tmp-s3-from-to 
#cat ${S3_DL}/tmp-s3-ls


join ${S3_DL}/tmp-s3-from-to ${S3_DL}/tmp-s3-ls-from-to > ${S3_DL}/tmp-s3-dl
cat ${S3_DL}/tmp-s3-dl 

for dl in $(cat ${S3_DL}/tmp-s3-dl | awk '{print $3}'); do
  aws s3 cp s3://logs.wnc.solairo-ai.com/backup/ur/${dl} ${S3_DL}/
done


cat ${S3_DL}/tmp-s3-dl | while read line
do
  d=`echo $line | awk '{print $2}'`
  s=`echo $line | awk '{print $3}'`
  mv ${S3_DL}/$s ${S3_DL}/$d/
done

exit 0



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
