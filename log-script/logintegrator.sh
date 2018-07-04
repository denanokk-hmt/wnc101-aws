#!/bin/bash -evx

########################################
# Logrotate & S3 uploader
#
# 引数
# $1:統合する期間 YYYYMMDD-YYYYMMDD 
# $2:顧客(例：Urban researc->ur)
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
LANG=ja_JP.UTF-8
SYSD=$(pwd)
ENV=${SYSD}/ENV/env
S3_DL=${SYSD}/S3_DL
tmp=${S3_DL}/tmp


################################
#S3 DL先Dir作成
################################
if [ -e ${S3_DL} ]; then
  :
else
  mkdir ${S3_DL}
  ERR_CHK "S3 DLディレクトの作成"
fi


#########################
#レポートの清掃
rm -rf ${SYSD}/REPORT
ERR_CHK "REPORTディレクトを初期化"

mkdir ${SYSD}/REPORT
ERR_CHK "REPORTディレクトの作成"

mkdir ${SYSD}/REPORT/RANDOM
ERR_CHK "RANDOMディレクトの作成"

################################
#引数
################################
CUST=$1
FROM_TO=$2
FROM=${FROM_TO:0:8}
TO=${FROM_TO:9:8}
RANDOM_QTY=${3:-20}


################################
#VALIDATION FROM-TO
################################
if [ -z "$1" ]; then
  echo "[VALID ERR] dose not set 1st arg FROM-TO."
  exit 0
fi
expr "${FROM} + 1" > /dev/null 2>&1
if [ $? -lt 2 ] ; then
  :
else
  echo "FROM of FROM-TO dose not number."
  exit 0
fi
expr "${TO} + 1" > /dev/null 2>&1
if [ $? -lt 2 ] ; then
  :
else
  echo "TO of FROM-TO dose not number."
  exit 0
fi
if [ "${#FROM}" -eq 8 ]; then
  :
else
  echo "FROM of FROM-TO dose not 8 char. YYYYMMDD."
  exit 0
fi
if [ "${#TO}" -eq 8 ]; then
  :
else
  echo "TO of FROM-TO dose not 8 char. YYYYMMDD."
  exit 0
fi
#if [ "`date +'%Y%m%d' -d ${FROM} 2> /dev/null`" == ${FROM} ]; then
#  :
#else
#  echo "FROM of FROM-TO is ng."
#  exit 0
#fi
#if [ "`date +'%Y%m%d' -d ${TO} 2> /dev/null`" == ${TO} ]; then
#  :
#else
#  echo "TO of FROM-TO is ng."
#  exit 0
#fi
if [ ${FROM} -gt ${TO} ]; then
  echo "[VALID ERR] You set FROM-TO is not right."
  exit 0
fi


################################
#VALIDATION2
################################
if [ -z "${CUST}" ]; then
  echo "[VAILD ERR] dose not set customer.${CUST}"
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
echo "S3バケットのログ情報取得中..."
aws s3 ls ${S3_BUCKET_ADDR}/backup/${CUST} --recursive | cut -d"/" -f3 > $tmp-s3-ls
ERR_CHK "S3バケットのログ情報取得"
cat $tmp-s3-ls | awk 'BEGIN {FS="."} {print $1,$2,sprintf("%s.%s.%s",$1,$2,$3)}' | sort > $tmp-s3-ls-from-to      


################################
#S3からホスト名を取得(uniq)
################################
echo "アプリサーバーホスト情報取得中..."
HOST_NAMES=`cat $tmp-s3-ls | cut -d"/" -f3 | cut -d"." -f2`
rm -f $tmp-s3-hosts*
for host in $(echo ${HOST_NAMES}); do
  echo $host >> $tmp-s3-hosts
done
cat $tmp-s3-hosts | awk '!colname[$1]++{print $1}' | sort > $tmp-s3-hosts-uniq


################################
#ホスト名Dirを作成
################################
echo "アプリサーバーホストDir作成中..."
for host in $(cat $tmp-s3-hosts-uniq); do
  if [ -d "${S3_DL}/$host" ]; then
    :
  else
    mkdir ${S3_DL}/$host
    mkdir ${S3_DL}/$host/access
    mkdir ${S3_DL}/$host/system
    mkdir ${S3_DL}/$host/error
  fi
  ERR_CHK "S3_DLにホスト名Dirの確認or作成"
done


#########################
#S3からログをDL
echo "S3から指定期間に該当するログデータをダウンロード中..."
cat $tmp-s3-ls | 
cut -d "." -f1 | 
awk -v from=${FROM} -v to=${TO} 'BEGIN {FS="-"} $2>=from&&$1<from || $1>=from&&$2<=to || $1<=to&&$2>=from {print $1,$2}' | awk '!colname[$1$2]++{print $1,$2}' | sort | awk '{print(sprintf("%s-%s",$1,$2))}' > $tmp-s3-from-to

join $tmp-s3-from-to $tmp-s3-ls-from-to > $tmp-s3-dl

for dl in $(cat $tmp-s3-dl | awk '{print $3}'); do
  aws s3 cp s3://logs.wnc.solairo-ai.com/backup/ur/${dl} ${S3_DL}/
done
ERR_CHK "S3からログを取得"


#########################
#DLしたログを解凍した後、それぞれのホストDirに振り分ける
echo "ダウンロードしたログデータを振り分け中..."
cat $tmp-s3-dl | while read line
do
  d=`echo $line | awk '{print $2}'`   #ホスト名Dir
  s=`echo $line | awk '{print $3}'`   #zipファイル
  mv ${S3_DL}/$s ${S3_DL}/$d/         #ホスト名Dirにzipを移動
  unzip ${S3_DL}/$d/$s -d ${S3_DL}/$d #zipを解凍
  rm -f ${S3_DL}/$d/$s                #zipを削除
  mkdir ${S3_DL}/$d/access/${FROM_TO}
  mkdir ${S3_DL}/$d/system/${FROM_TO}
  mkdir ${S3_DL}/$d/error/${FROM_TO}
  find ${S3_DL}/$d -type f -name "*access.log" | xargs -IX mv X ${S3_DL}/$d/access/${FROM_TO}
  find ${S3_DL}/$d -type f -name "*system.log" | xargs -IX mv X ${S3_DL}/$d/system/${FROM_TO}
  find ${S3_DL}/$d -type f -name "*error.log" | xargs -IX mv X ${S3_DL}/$d/error/${FROM_TO}
  rm -rf ${S3_DL}/$d/usr
done
ERR_CHK "ログファイルの振り分け"


#########################
#振り分けたログファイルから期間外のログを削除
echo "不必要なログデータを削除中..."
cat $tmp-s3-dl | while read line
do
  d=`echo $line | awk '{print $2}'`   #ホスト名Dir

  ls ${S3_DL}/$d/access/${FROM_TO}/*  | 
  awk 'BEGIN {FS="/"} {print $NF}'    |
  awk -v from=${FROM} -v to=${TO} 'BEGIN {FS="_"} $1<from || $1>to {print}' | 
  xargs -IX rm -f ${S3_DL}/$d/access/${FROM_TO}/X  

  ls ${S3_DL}/$d/system/${FROM_TO}/*  | 
  awk 'BEGIN {FS="/"} {print $NF}'    |
  awk -v from=${FROM} -v to=${TO} 'BEGIN {FS="_"} $1<from || $1>to {print}' | 
  xargs -IX rm -f ${S3_DL}/$d/system/${FROM_TO}/X  

  ls ${S3_DL}/$d/error/${FROM_TO}/*   | 
  awk 'BEGIN {FS="/"} {print $NF}'    |
  awk -v from=${FROM} -v to=${TO} 'BEGIN {FS="_"} $1<from || $1>to {print}' | 
  xargs -IX rm -f ${S3_DL}/$d/error/${FROM_TO}/X  
done

 
#########################
#振り分けたログファイルを統合する
echo "ログデータを統合中..."
cat $tmp-s3-dl | while read line
do
  d=`echo $line | awk '{print $2}'`   #ホスト名Dir

  if [ -z "$(ls ${S3_DL}/$d/access/${FROM_TO})" ]; then
    :
  else
    cat ${S3_DL}/$d/access/${FROM_TO}/* >> ${S3_DL}/$d/access/${FROM_TO}.access.log
    cp ${S3_DL}/$d/access/${FROM_TO}.access.log ${SYSD}/REPORT/$d.${FROM_TO}.access.log 
  fi
  rm -rf ${S3_DL}/$d/access/${FROM_TO}/

  if [ -z "$(ls ${S3_DL}/$d/system/${FROM_TO})" ]; then
    :
  else
    cat ${S3_DL}/$d/system/${FROM_TO}/* >> ${S3_DL}/$d/system/${FROM_TO}.system.log
    cat ${S3_DL}/$d/system/${FROM_TO}.system.log | awk 'BEGIN {FS="|";OFS=","} {print($2,sprintf("\"%s\"",$3),sprintf("\"%s\"",$4),sprintf("\"%s\"",$5),sprintf("\"%s\"",$6))}' > ${SYSD}/REPORT/$d.${FROM_TO}.system.log.csv 
  fi
    rm -rf ${S3_DL}/$d/system/${FROM_TO}/
  
  if [ -z "$(ls ${S3_DL}/$d/error/${FROM_TO})" ]; then
    :
  else
    cat ${S3_DL}/$d/error/${FROM_TO}/* >> ${S3_DL}/$d/error/${FROM_TO}.error.log
    cp ${S3_DL}/$d/error/${FROM_TO}.error.log ${SYSD}/REPORT/$d.${FROM_TO}.error.log
  fi
  rm -rf ${S3_DL}/$d/error/${FROM_TO}/
done
ERR_CHK "ログファイルの統合"


#########################
#ランダムにシステムログを抜き出し、システムログを結合
echo "システムログを統合中..."
cat ${SYSD}/REPORT/*.${FROM_TO}.system.log.csv > $tmp-sys-i
nl $tmp-sys-i | sed $'s/\t/,/g' | sed -e 's/^ *//g' | sed -e 's/quest://g' | sed -e 's/answer://g' | sed -e 's/intents://g' | sed -e 's/entities://g' > $tmp-sys-i-nl
cat $tmp-sys-i-nl | awk 'BEGIN{FS=",";OFS=","} {print $1,$2}' | sed -e 's/]/],/g' > $tmp-sys-i-dt
#join
join -t"," -o 1.1,1.3,2.3,2.4,2.5,2.6 $tmp-sys-i-dt $tmp-sys-i-nl | sort > $tmp-sys-i-d
perl -MList::Util=shuffle -e 'print shuffle(<>)' < $tmp-sys-i-d | tail -n ${RANDOM_QTY} > $tmp-sys-i-random
echo "no,datetime,quest,answer,intent,entity" > ${SYSD}/REPORT/RANDOM/${FROM_TO}.random${RANDOM_QTY}.system.log.csv
cat $tmp-sys-i-random | sort -t "," -k1 -n >> ${SYSD}/REPORT/RANDOM/${FROM_TO}.random${RANDOM_QTY}.system.log.csv


#########################
#$tmpファイルの清掃
rm -f $tmp-*


echo "Exec fin."
echo "Complete. Please check REPORT Folder."

exit 0
