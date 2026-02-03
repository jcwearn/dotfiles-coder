 # History search with Ctrl+p/n                                                                                                                       
 bindkey '^P' history-beginning-search-backward                                                                                                       
 bindkey '^N' history-beginning-search-forward                                                                                                        
 bindkey '^F' forward-char                                                                                                                            
 bindkey '^B' backward-char                                                                                                                           
                                                                                                                                                      
 # History settings                                                                                                                                   
 HISTSIZE=10000                                                                                                                                       
 SAVEHIST=10000                                                                                                                                       
 HISTFILE=~/.zsh_history                                                                                                                              
 setopt SHARE_HISTORY                                                                                                                                 
 setopt HIST_IGNORE_DUPS                                                                                                                              
 setopt HIST_IGNORE_SPACE                                                                                                                             
                                                                                                                                                      
 # Useful aliases                                                                                                                                     
 alias ll='ls -la'                                                                                                                                    
 alias la='ls -A'                                                                                                                                     
 alias l='ls -CF'                                                                                                                                     
 alias ..='cd ..'                                                                                                                                     
 alias ...='cd ../..'                                                                                                                                 
                                                                                                                                                      
 # Enable color support                                                                                                                               
 autoload -U colors && colors  