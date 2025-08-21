SNOWFLAKE_REPO=innqkwc-wc59598.registry.snowflakecomputing.com/spcs_app/napp/img_repo
ROUTER_IMAGE=falkordb_router
FALKORDB_IMAGE=falkordb_server

help:            ## Show this help.
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

all: login build push

login:           ## Login to Snowflake Docker repo
	docker login $(SNOWFLAKE_REPO)

build: build_router build_falkordb  ## Build Docker images for Snowpark Container Services

build_router:    ## Build Docker image for router for Snowpark Container Services
	cd router && docker build --platform linux/amd64 -t $(ROUTER_IMAGE) . && cd ..

build_falkordb:  ## Build Docker image for FalkorDB for Snowpark Container Services
	cd falkordb && docker build --platform linux/amd64 -t $(FALKORDB_IMAGE) . && cd ..

push: push_router push_falkordb     ## Push Docker images to Snowpark Container Services

push_router:     ## Push router Docker image to Snowpark Container Services
	docker tag $(ROUTER_IMAGE) $(SNOWFLAKE_REPO)/$(ROUTER_IMAGE)
	docker push $(SNOWFLAKE_REPO)/$(ROUTER_IMAGE)

push_falkordb:   ## Push FalkorDB Docker image to Snowpark Container Services
	docker tag $(FALKORDB_IMAGE) $(SNOWFLAKE_REPO)/$(FALKORDB_IMAGE)
	docker push $(SNOWFLAKE_REPO)/$(FALKORDB_IMAGE)

build_and_push_falkordb: build_falkordb push_falkordb  ## Build and push FalkorDB image only

clean:           ## Remove local Docker images
	docker rmi -f $(ROUTER_IMAGE) $(FALKORDB_IMAGE) 2>/dev/null || true
