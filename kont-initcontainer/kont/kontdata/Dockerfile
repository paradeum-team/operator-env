FROM centos:7
COPY mysql /usr/bin/mysql
RUN  chmod 777 /usr/bin/mysql
COPY import.sh .
COPY *.sql /
ENTRYPOINT ["./import.sh"]
