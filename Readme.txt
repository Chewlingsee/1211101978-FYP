CALORIEWISE: CUSTOM DIET AND WORKOUT PLANNER


Description
-----------

This is a text file that describe how to run the files and application, . The datasets are put inside the model folder inside the app folder including recipe and workouts dataset, while the food image dataset is in the img_calssification.zip file. Besides, details about the datasets are given below the dataset section.


Datasets
--------

1. Recipe Dataset: 

This recipe dataset is self-collected with a combination of data from Edamam Recipe Search API and Food.com - Recipes and Review (a public dataset from Kaggle). It have been organized and preprocessed. Just download from below link to have more information: https://1drv.ms/x/c/a8034d40685ebc6b/EcdrpdfliyBAhuoyWA4EyaMBRyVb0eTDuY9hPnqj3nxnyg?e=7IvCWn OR https://www.kaggle.com/datasets/chewlingsee/caloriewise-recipe-dataset

2. Workout Dataset:

This workout dataset is self-collected from Compendium of Physical Activities - 2024 Adult Compendium (https://pacompendium.com/adult-compendium/). The dataset have saved in to a csv file and can be downloaded with the link: https://1drv.ms/x/c/a8034d40685ebc6b/EeP7_UURx4lGoNQrhuhD3SABhMQC7jp4v5beDeLaKFGptg?e=rJaQvF OR https://www.kaggle.com/datasets/chewlingsee/caloriewise-workout-dataset

3. Food Image Dataset: 

The food classification model is trained using a public dataset from Kaggle named Food Image Classification Dataset. The dataset can be downloaded from: https://www.kaggle.com/datasets/harishkumardatalab/food-image-classification-dataset

Installation
------------
1. Visual Studio Code  (https://code.visualstudio.com/docs/?dv=win64user)
2. Android Studio installation and setup (https://docs.flutter.dev/get-started/install/windows/mobile)
3. Flutter (https://docs.flutter.dev/install/with-vs-code)
3. MySQL Workbench 8.0 CE/ XAMPP (https://dev.mysql.com/downloads/workbench/)
4. Flutter extension
5. Dart extension

How to Run the Source Code
--------------------------

First, extract all the zip files.

- Dataset：
1. Run the recipe1.ipynb code (Data from Edamam Recipe Search API).
2. Run recipe2.ipynb (Food.com - Recipes and Review) to get the final combined and cleaned recipe dataset CSV file.

- Image Recognition Model:
1. Run img_classification.ipynb to train the model using the images from img folder.

- Application:
1. Run the app.py file from the app folder.
2. Run the caloriewise folder in Visual Studio Code.
3. Choose an android studio mobile emulator device.
4. In menu bar or the Visual Studio Code, run section click on run without debugging to start the application.


User Manual
-----------

1. Register an account using the sign in below the Login Page.
2. Fill up the personal survey form.
3. After successfully register, login to the account using email and password.
4. Go to Plan page to generate diet and workout plan.
5. After that, back to home page to view the daily actual intake and the daily plan.
6. Tick the check box if completed that particular meal, else go to Upload Page to add new intake.
7. In the Upload Page, click the upload container or gallery to upload an image from the gallery after saving an image, else take a photo using camera.
8. The predicted output will printed at the search bar, and a list of relevant recipes will be shown. 
9. Search bar can be used to search other food recipe with just typing and click on the search icon.
10. Click on the recipe that intake to view details and click on the add to intake button to add that recipe to daily meal plan. 
11. Profile Page can be access through the side bar at the top right of the corner.
12. The details information will be shown and an edit button can used to modify the personal information.
13. In the Tracking Page, user may view the daily actual calorie intake history and the weight updated progress through bar chart and line chart.
14. User may update weight progress per week using the update container. 
15. The latest weight will be stored and matrices data will be updated to ensure the next recommendation is accurate and consistency with the user latest condition.
16. Lastly, logout the account using the log out button in the side bar.