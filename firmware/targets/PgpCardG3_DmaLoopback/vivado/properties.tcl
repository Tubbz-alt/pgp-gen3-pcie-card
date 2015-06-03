
#set_property strategy Performance_Explore [get_runs impl_1]
#set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

#set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED false [get_runs impl_1]
#set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.IS_ENABLED false [get_runs impl_1]
#set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE NoBramPowerOpt [get_runs impl_1]
