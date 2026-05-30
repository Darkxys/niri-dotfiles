function ollama-on
    set model $argv[1]
    test -z "$model"; and echo "Usage: ollama-on <model>"; and return 1

    if not ss -ltn | grep -q ':11434'
        env OLLAMA_HOST=0.0.0.0:11434 OLLAMA_FLASH_ATTENTION=1 nohup ollama serve >/tmp/ollama.log 2>&1 &
        echo $last_pid >/tmp/ollama.pid
        sleep 1
    end

    curl -s http://127.0.0.1:11434/api/generate \
        -d "{\"model\":\"$model\",\"prompt\":\"Say ready in one word.\",\"stream\":false,\"keep_alive\":\"30m\"}"

    echo
end