 #!/bin/bash

if [ $DATABASE == "apolloportaldb" ];then 
 mysql -h $HOST -u$USER -p$PASSWORD --database=$DATABASE -e "update ServerConfig set value='[{"orgId":"hisun","orgName":"GY"},{"orgId":"paradeum","orgName":"PLD"}]' where id=2;"
else
 echo "SQL does not need to be updated"
fi


