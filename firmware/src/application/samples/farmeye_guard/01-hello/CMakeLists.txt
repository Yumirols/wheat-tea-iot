# 将当前目录下的 helloworld.c 文件添加进变量 SOURCES 中
# 工程最后编译时，将会编译  helloworld.c 文件
set(SOURCES "${SOURCES}" "${CMAKE_CURRENT_SOURCE_DIR}/helloworld.c" 
PARENT_SCOPE)