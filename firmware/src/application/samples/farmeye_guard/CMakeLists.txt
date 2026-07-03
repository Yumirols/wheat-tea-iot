if(DEFINED CONFIG_ENABLE_HELLOWORLD)
add_subdirectory_if_exist(01-hello)
endif()

if(DEFINED CONFIG_ENABLE_LED)
add_subdirectory_if_exist(06-led)
endif()

if(DEFINED CONFIG_ENABLE_BEEP)
add_subdirectory_if_exist(07-beep)
endif()

if(DEFINED CONFIG_ENABLE_UART)
add_subdirectory_if_exist(11-uart)
endif()

if(DEFINED CONFIG_ENABLE_DHT11)
add_subdirectory_if_exist(12-dht11)
endif()

if(DEFINED CONFIG_ENABLE_ADC)
add_subdirectory_if_exist(13-adc)
endif()

if(DEFINED CONFIG_ENABLE_CO2)
add_subdirectory_if_exist(14-co2)
endif()

if(DEFINED CONFIG_ENABLE_VOICE)
add_subdirectory_if_exist(19-voice)
endif()

if(DEFINED CONFIG_ENABLE_FARMEYE_GUARD)
add_subdirectory_if_exist(main)
endif()

# 单元测试
add_subdirectory_if_exist(tests)

set(SOURCES "${SOURCES}" PARENT_SCOPE)
set(PUBLIC_HEADER "${PUBLIC_HEADER}" ${HEADER_LIST} PARENT_SCOPE)
set(LIBS "${LIBS}" PARENT_SCOPE)
