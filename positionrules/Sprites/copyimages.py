import shutil

for i in xrange(-1, 24, 8):
	for j in xrange(1, 4):
			for k in xrange(1, 5):
				shutil.copyfile("text_there_%d_%d.png" % (i % 32, j), "text_there_%d_%d.png" % ((i + k) % 32, j))