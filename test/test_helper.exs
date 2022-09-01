# https://github.com/whitfin/local-cluster#setup
:ok = LocalCluster.start()
Application.ensure_all_started(:manifold)

ExUnit.start()
