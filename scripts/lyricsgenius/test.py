import lyricsgenius
genius = lyricsgenius.Genius(
    '6RC5iqtqnAWPhMEEOwK2Ows-8ZIbdNB_F4qdnys6lbvxZOTocBePAPqQtHBBldQA')

artist = genius.search_artist("Andy Shauf", max_songs=3, sort="title")
print(artist.songs)
