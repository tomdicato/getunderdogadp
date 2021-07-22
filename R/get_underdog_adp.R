library(RSelenium)
library(here)
library(tidyverse)
library(gert)
library(httr)

directory = str_replace_all(paste0(here(),"/data"), "/", "\\\\")

eCaps <- list(
  chromeOptions =
    list(prefs = list(
      "profile.default_content_settings.popups" = 0L,
      "download.prompt_for_download" = FALSE,
      "download.default_directory" = directory
    ))
)

login = "https://underdogfantasy.com/login"

email_address <-  Sys.getenv("ud_user")

pw <- Sys.getenv("ud_pass")

rd <- rsDriver(port = sample(4422:4777, 1),
               browser = "chrome",
               extraCapabilities = eCaps,
               chromever = "91.0.4472.101")

rem_dr <- rd[["client"]]

rem_dr$navigate(login)

Sys.sleep(runif(1, .5, 1.5))

email = rem_dr$findElement(using= 'xpath', value = '//*[contains(concat( " ", @class, " " ), concat( " ", "styles__fieldWrapper__2hUuY", " " )) and (((count(preceding-sibling::*) + 1) = 1) and parent::*)]//*[contains(concat( " ", @class, " " ), concat( " ", "styles__field__3fmc7", " " ))]')

email$sendKeysToElement(list(email_address))

Sys.sleep(runif(1, .5, 1.5))

password = rem_dr$findElement(using = 'css', value = '.styles__fieldWrapper__2hUuY+ .styles__fieldWrapper__2hUuY .styles__field__3fmc7')
password$sendKeysToElement(list(pw))

Sys.sleep(runif(1, .5, 1.5))

login_button = rem_dr$findElement(using="css", value = ".styles__button__1PEcx")
login_button$clickElement()

Sys.sleep(runif(1, 3, 5))

rem_dr$navigate("https://underdogfantasy.com/rankings/NFL/87a5caba-d5d7-46d9-a798-018d7c116213")

Sys.sleep(runif(1, 3, 5))

csv_uploaddownload <- rem_dr$findElement(using = "css", value = '#root > div > div > div.styles__rankingSection__3uXmq > div.styles__playerListColumn__gxVDk > div.styles__rankingsButtons__2mQJG > button')
csv_uploaddownload$clickElement()

Sys.sleep(runif(1, 3, 5))

csv_download <- rem_dr$findElement(using = "css", value ='#root > div > div > div.styles__rankingUpload__2yN53 > div > div.styles__uploadButtons__3MAkt > a')
csv <- csv_download$clickElement()

Sys.sleep(1)

rem_dr$closeWindow()

list.files(path = directory)

files <- list.files(directory, pattern = "rankings-")

setwd(directory)

current_time <- format(Sys.time(), "%Y-%m-%d-T%H%M")

formatted_adp <-
  read_csv(files[1], ) %>%
  filter(adp != "-") %>%
  mutate(adp_date = current_time,
         adp = as.double(adp))

saveRDS(formatted_adp, file = paste0(here(), "/data/ud_adp_", current_time, ".rds"))

saveRDS(formatted_adp, file = paste0(here(), "/data/ud_adp_current.rds"))

file.remove(files[1])

req <- GET(
  "https://api.github.com/repos/DangyWing/Underdog-ADP/git/trees/main?recursive=1",
  authenticate(Sys.getenv("GITHUB_PAT_DANGY"), "")
)

### Helper Functions ###

parse_raw_rds <- function(raw) {
  con <- gzcon(rawConnection(raw))

  on.exit(close(con))

  readRDS(con) %>%
    tibble::tibble()
}

get_rds <- function(url) {

  url_clean <- paste0("https://raw.githubusercontent.com/DangyWing/Underdog-ADP/main/", url)

  x <- GET(
    url_clean,
    authenticate(Sys.getenv("GITHUB_PAT_DANGY"), "")
  )

  content(x, as = "raw") %>%
    parse_raw_rds()

}

if(!user_is_configured()){
  git_config_set("user.name", "Dangy")
  git_config_set("user.email", "dangywing@gmail.com")
}

gert::git_add(file = paste0("/data/ud_adp_", current_time, ".rds"))
gert::git_add(file = "/data/ud_adp_current.rds")

git_commit_all(message = "Updated UD ADP")

gert::git_push()
# file.rename(files, to = paste0("ud_adp_raw_current",current_time, ".csv"))

req <- GET(
  "https://api.github.com/repos/DangyWing/Underdog-ADP/git/trees/main?recursive=1",
  authenticate(Sys.getenv("GITHUB_PAT_DANGY"), "")
)

filelist <-
  unlist(lapply(content(req)$tree, "[", "path"), use.names = F)

total_ud_adp <-
  grep("[0-9].rds", filelist, value = TRUE) %>%
  map_dfr(get_rds)

total_ud_adp %>%View


saveRDS(total_ud_adp, file = paste0(here(), "/data/ud_adp_total.rds"))

if(!user_is_configured()){
  git_config_set("user.name", "Dangy")
  git_config_set("user.email", "dangywing@gmail.com")
}

gert::git_add(file = "/data/ud_adp_total.rds")

git_commit_all(message = "Updated UD total ADP")

gert::git_push()

directory = str_replace_all(paste0(here(),"/data"), "/", "\\\\")

files <- list.files(directory, pattern = "ud_adp_total.rds")

setwd(directory)

file.remove(files[1])

setwd(here())
