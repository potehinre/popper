import popper
if __name__ == '__main__':
    pusher = popper.Pusher()
    data_str = {"message":"hello from REST"}
    pusher['presence-chat'].trigger('chat_msg',data=data_str)
    
