# lservice2

lservice implements a model: 
a separate luajit vm running inside a separate thread with a message queue (inbox). the thread wakes up whenever a new message arrives and then begins to process the message.

the design is largely inspired by cloudwu's skynet/ltask, although the model itself is much more simpler. 

# message

A message contains four elements: