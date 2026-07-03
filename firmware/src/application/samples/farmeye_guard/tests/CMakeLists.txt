set(SOURCES_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/test_main.c
)

set(HEADER_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/../main
    ${CMAKE_CURRENT_SOURCE_DIR}/../main/dht11
    ${CMAKE_CURRENT_SOURCE_DIR}/../main/co2
    ${CMAKE_CURRENT_SOURCE_DIR}/../main/hcsr04
    ${CMAKE_CURRENT_SOURCE_DIR}/../main/led
    ${CMAKE_CURRENT_SOURCE_DIR}/../main/beep
    ${CMAKE_CURRENT_SOURCE_DIR}/../main/relay
    ${CMAKE_CURRENT_SOURCE_DIR}/../main/oled
)

if(DEFINED CONFIG_TEST_DHT11)
    set(SOURCES_LIST ${SOURCES_LIST}
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/dht11/dht11.c
        ${CMAKE_CURRENT_SOURCE_DIR}/test_dht11.c
    )
endif()

if(DEFINED CONFIG_TEST_CO2)
    set(SOURCES_LIST ${SOURCES_LIST}
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/co2/co2.c
        ${CMAKE_CURRENT_SOURCE_DIR}/test_co2.c
    )
endif()

if(DEFINED CONFIG_TEST_ULTRASONIC)
    set(SOURCES_LIST ${SOURCES_LIST}
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/hcsr04/hcsr04.c
        ${CMAKE_CURRENT_SOURCE_DIR}/test_ultrasonic.c
    )
endif()

if(DEFINED CONFIG_TEST_LED_BEEP)
    set(SOURCES_LIST ${SOURCES_LIST}
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/led/led.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/beep/beep.c
        ${CMAKE_CURRENT_SOURCE_DIR}/test_led_beep.c
    )
endif()

if(DEFINED CONFIG_TEST_RELAY)
    set(SOURCES_LIST ${SOURCES_LIST}
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/relay/relay.c
        ${CMAKE_CURRENT_SOURCE_DIR}/test_relay.c
    )
endif()

if(DEFINED CONFIG_TEST_OLED)
    set(SOURCES_LIST ${SOURCES_LIST}
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/oled/oled.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/oled/bsp_oled.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/oled/oled_fonts.c
        ${CMAKE_CURRENT_SOURCE_DIR}/test_oled.c
    )
endif()

if(DEFINED CONFIG_TEST_ALARM)
    set(SOURCES_LIST ${SOURCES_LIST}
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/app_main.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/led/led.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/beep/beep.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../main/relay/relay.c
        ${CMAKE_CURRENT_SOURCE_DIR}/test_alarm.c
    )
endif()

set(SOURCES "${SOURCES}" ${SOURCES_LIST} PARENT_SCOPE)
set(PUBLIC_HEADER "${PUBLIC_HEADER}" ${HEADER_LIST} PARENT_SCOPE)
