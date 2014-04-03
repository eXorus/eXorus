!/bin/bash

#---------------------------------------------------------------#
# Paramétrage de la connection MySQL                            #
#---------------------------------------------------------------#

#Nom de l'utilisateur qui lance le backup
user=mysql-backup-manager
#Machine sur laquelle on se connecte
host=localhost
#Mot de passe de l'utilisateur de backup
pass=mon_mot_de_passe_system

# Outil de dump
MYSQLDUMP=mysqldump
#Outil de check
MYSQLCHECK=mysqlcheck
# Options passées |  MYSQLDUMP
OPTIONS="--add-drop-database  --add-drop-table --complete-insert --routines --triggers --max_allowed_packet=250M --force"

#---------------------------------------------------------------#
# Paramétrage de la sauvegarde                                  #
#---------------------------------------------------------------#

# Répertoire temporaire pour stocker les backups
TEMPORAIRE="/home/MySQLBackupManager/tmp"

# Nom du serveur
MACHINE="$(hostname)"

# Date jour
DATE_DAILY="$(date +"%Y-%m-%d")"
#Retention des sauvegardes journalières
DAILY_RETENTION=15

# Date semaine
DATE_WEEKLY="$(date +"%U")"
#Retention des sauvegardes hebdomadaires
WEEKLY_RETENTION=200

# Nom des fichiers de backup
# Répertoire de destination du backup
REP_DAILY="backups_daily"
REP_WEEKLY="backups_weekly"
DESTINATION_DAILY="/home/MySQLBackupManager/"$REP_DAILY
DESTINATION_WEEKLY="/home/MySQLBackupManager/"$REP_WEEKLY
FICHIER_BACKUP_DAILY=$MACHINE"_BACKUP_MYSQL_"$DATE_DAILY".tar.gz"
FICHIER_BACKUP_WEEKLY=$MACHINE"_BACKUP_MYSQL_S"$DATE_WEEKLY".tar.gz"

#Informations FTP
LOGIN_FTP=sd-xxxx
PASS_FTP=mon_mot_de_passe_ftp
HOST_FTP=dedibackup-dc2.online.net
FTP_DAILY=$MACHINE"/"$REP_DAILY
FTP_WEEKLY=$MACHINE"/"$REP_WEEKLY

#---------------------------------------------------------------#
# Process de sauvegarde                                         #
#---------------------------------------------------------------#
# Création du répertoire temporaire
if [ -d $TEMPORAIRE ];
then
  echo "Le repertoire "$TEMPORAIRE" existe.";
else
  mkdir $TEMPORAIRE;
  echo "Création du repertoire "$TEMPORAIRE".";
fi

# On construit la liste des bases de données
BASES="$(mysql -u $user -h $host -p$pass -Bse 'show databases')"

# On lance le dump des bases
for db in $BASES
do
  if [ $db != "information_schema" ]; then
    #On lance un check et une analyse pour chaque base de données
    $MYSQLCHECK -u $user -h $host -p$pass -c -a $db
    # On lance un mysqldump pour chaque base de données
    $MYSQLDUMP -u $user -h $host -p$pass $OPTIONS $db -R > $TEMPORAIRE"/"$MACHINE"-"$db"-"$DATE_DAILY".sql";
  fi
done

# Création du répertoire de destination journalier
if [ -d $DESTINATION_DAILY ];
then
  echo "Le repertoire "$DESTINATION_DAILY" existe.";
else
  mkdir $DESTINATION_DAILY;
  echo "Création du repertoire "$DESTINATION_DAILY".";
fi

# Création de l'archive contenant tout les dump
#Cette archive est stockée dans le dossier défini pour la sauvegarde
cd $TEMPORAIRE
tar -cvzf $DESTINATION_DAILY"/"$FICHIER_BACKUP_DAILY *

# Création du répertoire de destination semaine
if [ -d $DESTINATION_WEEKLY ];
then
  echo "Le repertoire "$DESTINATION_WEEKLY" existe.";
else
  mkdir $DESTINATION_WEEKLY;
  echo "Création du repertoire "$DESTINATION_WEEKLY".";
fi

#Copie de la sauvagarde semaine
if [ -f $DESTINATION_WEEKLY"/"$FICHIER_BACKUP_WEEKLY  ];
then
    echo "La sauvegarde "$DESTINATION_WEEKLY"/"$FICHIER_BACKUP_WEEKLY" existe.";
else
    echo "Création de la sauvegarde "$DESTINATION_WEEKLY"/"$FICHIER_BACKUP_WEEKLY".";
    cp $DESTINATION_DAILY"/"$FICHIER_BACKUP_DAILY $DESTINATION_WEEKLY"/"$FICHIER_BACKUP_WEEKLY
fi

# On supprime le fichier
find $DESTINATION_DAILY -type f -mtime +$DAILY_RETENTION | xargs -r rm
find $DESTINATION_WEEKLY -type f -mtime +$WEEKLY_RETENTION | xargs -r rm

# On transfere l'archive par FTP
lftp $HOST_FTP<<SCRIPTFTP
user $LOGIN_FTP $PASS_FTP
mirror -R $DESTINATION_DAILY"/" $FTP_DAILY"/"
mirror -R $DESTINATION_WEEKLY"/" $FTP_WEEKLY"/"
du -hs /
bye
SCRIPTFTP

# On suprime le répertoire temporaire
if [ -d $TEMPORAIRE ]; then
  rm -Rf $TEMPORAIRE
fi
