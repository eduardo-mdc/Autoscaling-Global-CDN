#!/bin/bash
VIDEO_PATH="/usr/share/nginx/html/files/BigBuckBunny.mp4"
RTMP_URL="rtmp://localhost:1935/live/stream"

ffmpeg -re -i "$VIDEO_PATH" -c:v copy -c:a aac -f flv "$RTMP_URL"