docker run -it \
	-e HOST="192.168.0.124" \
	-e USER="xxl_job" \
	-e PASSWORD="Hisun.11"	\
	-e DATABASE="xxl_job" \
	-e SQLFILE="xxl_job.sql" \
	xxx/library/kont-sqlinit:0.0.4 bash
