function ollama-off
    if test -f /tmp/ollama.pid
        kill (cat /tmp/ollama.pid) 2>/dev/null
        rm /tmp/ollama.pid
        echo "Ollama stopped."
    else
        pkill -x ollama
        echo "Ollama stopped."
    end
end
