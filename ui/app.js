import { createApp } from 'vue'

$(document).ready( () => {

    
    const app = createApp({
        data () {
            return {
                appOpen: false,
                unreads: 0, 
                pageShowing: null,
                isFocused: false,
                displayer: {
                    type: null,
                    url: null

                },
                userInfo: {
                    name: null, 
                    input: null,
                    mediaInput: null,
                },
                messages: []
            }
        },

        methods: {

            handleKeyUp(e) {
                if (  this.appOpen ) {
                    if (e.key === 'Escape') {
                        if ( !this.pageShowing ) {
                            this.appOpen = false
                            $('#chat').css('top', '95%')
                            $('#chat').css('opacity', 0.6)
                            $.post('http://browns_staffchat/closeApp')
                        } else if ( this.pageShowing === 'media' ) {
                            $('#media-displayer').hide('fade', 500)
                            this.pageShowing = null
                            this.displayer = {
                                type: null,
                                url: null
                            },
                            setTimeout(() => {
                                this.isFocused = false
                            }, 500);
                        } else if ( this.pageShowing === 'selector' ) {
                            $('#url-selector').hide('fade', 500)
                            this.pageShowing = null
                            this.userInfo.mediaInput = ''
                            setTimeout(() => {
                                this.isFocused = false
                            }, 500);
                        }
                    }
                }
            },

            setWaypoint(coords, index) {
                $.post('http://browns_staffchat/setWaypoint', JSON.stringify({
                    coords: coords
                }))

                this.messages[index].data.hasClickedWaypoint = true 
                setTimeout(() => {
                    this.messages[index].data.hasClickedWaypoint = false 
                }, 3500); 

            },
            displayMedia(type, url) {
                if ( this.isFocused ) { return }
                this.isFocused = true
                this.displayer.type = type
                this.displayer.url = url
                $('#media-displayer').show('fade', 500)
                this.pageShowing = 'media'
            },
            openMediaSelector() {
                if ( this.isFocused ) { return }
                this.isFocused = true
                $('#url-selector').show('fade', 500)
                this.pageShowing = 'selector'
            },
            getMediaType() {
                return $('input[name="urltype"]:checked').val()
            },
            scrollToBottom() {
                setTimeout(() => {
                    var chatContainer = $('#chatarea');
                    chatContainer.animate({
                        scrollTop: chatContainer[0].scrollHeight
                    }, 500);
                }, 10);
            },
            createMessage(data) {

                if ( this.isFocused && data.contentType !== 'media' ) { return }

                if ( data.contentType === 'message' && data.data && !data.data.message ) {
                    data.data.message = " "
                }

                if ( data.contentType === 'message' && data.type === 'sent' ) {
                    this.userInfo.input = ''
                }

                const Data = {
                    name: data.name, 
                    type: data.type,
                    contentType: data.contentType || "message",
                    data: data.data || {
                        message: " ",
                        coords: null, 
                        url: null, 
                        urlType: null
                    }
                }

                if (Data.contentType === 'location') {
                    $.post('http://browns_staffchat/getLocation')
                    .then((location) => {
                        if ( location ) {
                            Data.data.coords = location
                            $.post('http://browns_staffchat/newMessage', JSON.stringify({
                                message: Data
                            }))
                            .then((success) => {
                                if (success) {
                                    this.messages.push(Data)
                                    this.scrollToBottom()
                                    if (data.contentType === 'media' && data.type === 'sent' && this.isFocused ) {
                                        this.pageShowing = null
                                        this.userInfo.mediaInput = ''
                                        $('#url-selector').hide('fade', 500)
                                        setTimeout(() => {
                                            this.isFocused = false
                                        }, 500);
                                    }
                                }
                            })
                            .fail((err) => {
                                console.log('error sending message', err)
                                if (data.contentType === 'media' && data.type === 'sent' && this.isFocused ) {
                                    this.pageShowing = null
                                    this.userInfo.mediaInput = ''
                                    $('#url-selector').hide('fade', 500)
                                    setTimeout(() => {
                                        this.isFocused = false
                                    }, 500);
                                }
                            })
                        }
                    })
                    .fail((err) => {
                        console.log('Error getting location for message', err)
                    })

                    return
                }

                $.post('http://browns_staffchat/newMessage', JSON.stringify({
                    message: Data
                }))
                .then((success) => {
                    if (success) {
                        this.messages.push(Data)
                        this.scrollToBottom()
                        if (data.contentType === 'media' && data.type === 'sent' && this.isFocused ) {
                            this.pageShowing = null
                            this.userInfo.mediaInput = ''
                            $('#url-selector').hide('fade', 500)
                            setTimeout(() => {
                                this.isFocused = false
                            }, 500);
                        }
                    }
                })
                .fail((err) => {
                    console.log('error sending message', err)
                    if (data.contentType === 'media' && data.type === 'sent' && this.isFocused ) {
                        this.pageShowing = null
                        this.userInfo.mediaInput = ''
                        $('#url-selector').hide('fade', 500)
                        setTimeout(() => {
                            this.isFocused = false
                        }, 500);
                    }
                })
            }
        },
        mounted() {
            $('#url-selector').hide()
            $('#media-displayer').hide()
            $('#chat').hide()
            window.addEventListener('keyup', this.handleKeyUp)
            window.addEventListener('message', (e) => {
                if (e.data.type === 'open') {
                    const data = e.data 
                    this.unreads = 0
                    this.pageShowing = null
                    this.isFocused = false
                    this.displayer = {
                        type: null,
                        url: null
                    },
                    this.userInfo = {
                        name: data.username, 
                        input: null,
                        mediaInput: null,
                    },
                    this.messages = data.messages || []
                    $('#chat').css('top', '80%')
                    setTimeout(() => {
                        this.appOpen = true
                        $('#chat').css('opacity', 1)
                        this.scrollToBottom()
                    }, 250);

                }

                if (e.data.type === 'newMessage') {
                    const data = e.data 
                    this.messages.push(data.message)

                    if ( !this.appOpen ) {
                        this.unreads = this.unreads + 1
                    }
                }

                if (e.data.type === 'playerLoaded') {
                    this.unreads = e.data.unreads 
                    this.appOpen = false
                    $('#chat').show('fade', 500)
                }

                if (e.data.type === 'removeAccess' ) {

                    $('#app').hide('fade', 500)
                    this.unreads = 0
                    this.pageShowing = null
                    this.isFocused = false
                    this.displayer = {
                        type: null,
                        url: null
                    },
                    this.userInfo = {
                        name: null, 
                        input: null,
                        mediaInput: null,
                    },
                    this.messages = []

                    if ( this.appOpen ) {
                        $.post('http://browns_staffchat/closeApp')
                    }

                    this.appOpen = false
                }
            })
        },
        onUnmounted() {
            window.removeEventListener('keyup', this.handleKeyUp)
        }
    })

    const App = app.mount('#app')
    const appData = App.$data
})