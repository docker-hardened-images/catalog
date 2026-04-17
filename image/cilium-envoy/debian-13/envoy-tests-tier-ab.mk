# Tier A + B subset for DHI image CI: unit tests plus one TCP integration test.
# Full `make envoy-tests` runs //tests/... and upstream tcp_proxy integration tests,
# which is very slow and pulls TLS integration cases tied to expiring test certs.
#
# Tier A: //:envoy_binary_test and //tests:* unit targets
# Tier B: //tests:cilium_tcp_integration_test
#
# Loaded after the upstream Makefile: `make -f Makefile -f envoy-tests-tier-ab.mk envoy-tests-ci`

.PHONY: envoy-tests-ci
envoy-tests-ci: $(COMPILER_DEP) SOURCE_VERSION proxylib/libcilium.so
	@$(ECHO_BAZEL)
	CARGO_BAZEL_REPIN=true $(BAZEL) $(BAZEL_OPTS) test $(BAZEL_BUILD_OPTS) $(BAZEL_TEST_OPTS) \
		//:envoy_binary_test \
		//tests:cilium_network_policy_test \
		//tests:metadata_config_test \
		//tests:accesslog_test \
		//tests:health_check_sink_test \
		//tests:cilium_tcp_integration_test \
		$(BAZEL_FILTER)
