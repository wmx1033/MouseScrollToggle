#!/bin/zsh
source "${0:A:h}/common.sh"
case ${1:-} in
  start) start_service ;;
  stop) stop_service; print 'STOPPED 已停止' ;;
  toggle) if health; then stop_service; print 'STOPPED 已停止'; else start_service; fi ;;
  status) state ;;
  *) fail '用法：control.sh start|stop|toggle|status' 64 ;;
esac
